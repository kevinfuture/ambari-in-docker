@echo off
chcp 65001
set /p input=Please enter your selection :


setlocal
set IMAGE_NAME=tungshuaishuai/ambari-repo:2.7.6.3
 
docker images --format "{{.Repository}}:{{.Tag}}" | findstr "%IMAGE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo 镜像 %IMAGE_NAME% 尚未拉取，现在拉取该镜像...
    docker pull %IMAGE_NAME%
) else (
    echo 镜像 %IMAGE_NAME% 已拉取。
)
endlocal

setlocal
set IMAGE_NAME=tungshuaishuai/ambari-node:2.7.6.3
 
docker images --format "{{.Repository}}:{{.Tag}}" | findstr "%IMAGE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo 镜像 %IMAGE_NAME% 尚未拉取，现在拉取该镜像...
    docker pull %IMAGE_NAME%
) else (
    echo 镜像 %IMAGE_NAME% 已拉取。
)
endlocal


set node_num=2

:create
    echo "create network..."
    route add -p 172.188.0.0 mask 255.255.0.0 192.168.8.147

    echo "start repo..."
    docker run -d --name ambari-repo  --network ambari_cluster_net  --add-host kaq.kj.com:127.0.0.1 --ip 172.188.0.2 -it  tungshuaishuai/ambari-repo:2.7.6.3

    echo "init init-hosts.sh..."
    replace "node_num=2" "node_num=%node_num%" init-hosts.sh


    echo "create ambari-server..."
    docker run -d --privileged --name amb-server   --network ambari_cluster_net --add-host kaq.kj.com:127.0.0.1 --ip 172.188.0.3 -p 8181:8080 -it  tungshuaishuai/ambari-node:2.7.6.3
    docker cp init-hosts.sh         amb-server:/root/
    docker cp init-ambari-server.sh amb-server:/root/

    for /L %%i in (0, 1, %node_num%) do (
        echo "create ambari-agent%%i%"
        docker run -d --privileged --name  "amb%%i%"   --network ambari_cluster_net  --add-host kaq.kj.com:127.0.0.1 --ip “172.188.0.3%%i%" -it  tungshuaishuai/ambari-node:2.7.6.3
        docker cp init-hosts.sh    amb$i:/root/
    )


    echo "do init-hosts..."
    docker exec -it amb-server bash /root/init-hosts.sh
    docker exec -it amb-server wget http://repo.hdp.link/ambari/centos7/2.7.6.3-2/ambari.repo -P /etc/yum.repos.d/
    docker exec -it amb-server wget http://repo.hdp.link/HDP/centos8/3.3.1.0-002/hdp.repo -P /etc/yum.repos.d/
    for %%i in (0, 1, %node_num%) do (
        docker exec -it "amb%%i%"   bash /root/init-hosts.sh
        docker exec -it "amb%%i%" wget http://repo.hdp.link/ambari/centos7/2.7.6.3-2/ambari.repo -P /etc/yum.repos.d/
        docker exec -it "amb%%i%" wget http://repo.hdp.link/HDP/centos8/3.3.1.0-002/hdp.repo -P /etc/yum.repos.d/
    )


    echo "init ambari-server"
    docker exec -it amb-server bash /root/init-ambari-server.sh
exit /b


:start
    echo "start!"
    docker start amb-server

    for %%i in (0, %node_num%) do (
        docker start amb$i
    )
    docker exec -it amb-server bash /root/init-hosts.sh
    docker exec -it amb-server ambari-server start
    docker exec -it amb-server ambari-agent start
    
    for %%i in (0, %node_num%) do (
        docker exec -it amb$i       bash /root/init-hosts.sh
        docker exec -it amb$i ambari-agent start
    )
exit /b



:stop
    echo "stop!"
    docker stop amb-server
    for %%i in (0, %node_num%) do (
        docker stop amb$i
    )
exit /b


if %input% == 'start'(
      call :start
)else if %input% == 'stop'(
     call :stop
)else if %input% == 'create'(
     call :create
)else(
    echo Usage: %input% {start|stop|create}
     exit 1
)
exit 0

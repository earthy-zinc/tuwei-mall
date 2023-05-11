## 虚拟机配置指南

### 硬件配置

| 节点名        | IP              | CPU  | 内存 |
| ------------- | --------------- | ---- | ---- |
| Pei-Linux-100 | 192.168.210.100 | 24   | 16   |
| Pei-Linux-101 | 192.168.210.101 | 4    | 8    |
| Pei-Linux-102 | 192.168.210.102 | 4    | 8    |
| Pei-Linux-103 | 192.168.210.103 | 4    | 8    |



### docker环境搭建

#### 安装docker

使用官方给出的脚本，https://get.docker.com/

```shell
# 获取并运行安装脚本
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
# 启动docker服务
systemctl start docker
# 配置docker开机自启
systemctl enable docker
```

#### 配置国内镜像

修改配置文件

```shell
sudo vi /etc/docker/daemon.json
```

添加内容

```json
{
    "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
```

重启docker

```shell
systemctl daemon-reload
systemctl restart docker
```

#### 注意事项：

如果以非 root 用户可以运行 docker 时，
需要执行 `sudo usermod -aG docker cmsblogs` 命令然后重新登陆，
否则会有如下报错

```md
docker: Cannot connect to the Docker daemon. 
Is the docker daemon running on this host ?
```

### mysql搭建

```bash
docker run --restart=always \
-d \
-p 3306:3306 \
--privileged=true \
-v /opt/docker_volume/mysql/log:/var/log/mysql \
-v /opt/docker_volume/mysql/data:/var/lib/mysql \
-v /opt/docker_volume/mysql/conf:/etc/mysql/conf.d \
-e MYSQL_ROOT_PASSWORD=123456 \
--name mysql \
mysql
```

### redis搭建

官网获取 `redis.conf` : http://www.redis.cn/download.html

解压后可在根目录查看到 `redis.conf` 配置文件，将其内容复制到 `/opt/docker_volume/redis/redis.conf`，然后修改以下内容：

- bind 127.0.0.1 ： 注释掉，redis可以外部访问
- --requirepass "123456" ： 设置Redis密码为123456，默认无密码
- --appendonly yes ： AOF持久化
- tcp-keepalive 60 ： 默认300，调小防止远程主机强迫关闭一个现有连接错误

```bash
docker run --restart=always \
--log-opt max-size=100m \
--log-opt max-file=2 \
-p 6379:6379 \
--name redis \
-v /opt/docker_volume/redis/redis.conf:/etc/redis/redis.conf \
-v /opt/docker_volume/redis/data:/data \
-d redis redis-server /etc/redis/redis.conf  \
--appendonly yes  \
--requirepass 123456
```

### rabbitmq搭建

```bash
docker run -d --restart=always \
--name rabbitmq  \
--hostname rabbitmq \
-p 15672:15672 \
-p 5672:5672 \
rabbitmq
```

- hostname: RabbitMQ存储数据的节点名称,默认是主机名,不指定更改主机名启动失败,默认路径
- p 指定宿主机和容器端口映射（5672：服务应用端口，15672：管理控制台端口）

#### 安装插件

```bash
# 打开bash
docker exec -it rabbitmq /bin/bash
# 安装插件
rabbitmq-plugins enable rabbitmq_management
```

#### 重置队列

```bash
docker exec -it rabbitmq /bin/sh
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app
```

#### 访问控制台

访问RabbitMQ控制台: [http://192.168.210.100:15672/](http://192.168.210.100:15672/)

用户名/密码：guest/guest

### nacos搭建

#### 创建数据库

运行[nacos-db.sql](../nacos/nacos-db.sql)在mysql中创建nacos数据库

#### 创建和启动容器

```bash
docker run -d --name nacos \
--restart=always \
## --network=host \
-p 8848:8848 \
-e MODE=standalone \
-e JVM_XMS=256m \
-e JVM_XMX=512m \
-e SPRING_DATASOURCE_PLATFORM=mysql \
-e MYSQL_SERVICE_HOST=192.168.210.100 \
-e MYSQL_SERVICE_PORT=3306 \
-e MYSQL_SERVICE_DB_NAME=nacos \
-e MYSQL_SERVICE_USER=root \
-e MYSQL_SERVICE_PASSWORD=123456 \
-e MYSQL_DATABASE_NUM=1 \
-e MYSQL_SERVICE_DB_PARAM="characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=true&serverTimezone=UTC" \
-v /opt/docker_volume/nacos:/home/nacos/logs \
nacos/nacos-server:2.0.3
```

* MYSQL_SERVICE_DB_NAME 数据库的名称
* MYSQL_SERVICE_USER 数据库用户名
* MYSQL_SERVICE_PASSWORD 数据库密码
* MYSQL_DATABASE_NUM 数据库数量

#### 访问控制台

控制台地址： [http://192.168.210.100:8848/nacos/index.html](http://192.168.210.100:8848/nacos/index.html)

默认用户名/密码：nacos/nacos

### seata搭建

#### 创建数据库
[seata.sql](../seata/seata.sql)
#### 配置

##### 1. 获取Seata外置配置

获取Seata外置配置
* 本地地址：[config.txt](../seata/config.txt)
* 在线地址：[config.txt](https://github.com/seata/seata/blob/1.5.2/script/config-center/config.txt)

##### 2. 导入外置配置

Nacos 默认**public** 命名空间下 ，新建Data ID 为 seataServer.properties 的配置，Group为SEATA_GROUP的配置，并将Seata外置配置config.txt内容全量复制进来

##### 3. 修改外置配置

seataServer.properties 需要修改存储模式为db和db连接配置

```properties
# 修改store.mode为db，配置数据库连接
store.mode=db
store.db.dbType=mysql
store.db.driverClassName=com.mysql.cj.jdbc.Driver
store.db.url=jdbc:mysql://192.168.210.100:3306/seata?useUnicode=true&rewriteBatchedStatements=true
store.db.user=root
store.db.password=123456
```

- **store.mode=db** 存储模式选择为数据库
- **store.db.url** MySQL主机地址
- **store.db.user** 数据库用户名
- **store.db.password** 数据库密码

#### 创建和启动容器

##### 1. 获取应用配置

按照官方文档描述使用**自定义配置文件**的部署方式，需要先创建临时容器把配置copy到宿主机

**创建临时容器**

```bash
docker run -d --name seata-server -p 8091:8091 -p 7091:7091 seataio/seata-server:1.5.2
```

**创建挂载目录**

```bash
mkdir -p /opt/docker_volume/seata/config
```

**复制容器配置至宿主机**

```bash
docker cp seata-server:/seata-server/resources/ /opt/docker_volume//seata/config
```

注意复制到宿主机的目录，下文启动容器需要做宿主机和容器的目录挂载

**过河拆桥，删除临时容器**

```bash
docker rm -f seata-server
```

##### 2. 修改启动配置

在获取到 seata-server 的应用配置之后，因为这里采用 Nacos 作为 seata 的配置中心和注册中心，所以需要修改 application.yml 里的配置中心和注册中心地址，详细配置我们可以从 application.example.yml 拿到。

**application.yml 原配置**

**修改后的配置**(参考 application.example.yml 示例文件)，以下是需要调整的部分，其他配置默认即可

```yaml
seata:
  config:
    type: nacos
    nacos:
      server-addr: 192.168.210.100:8848
      namespace:
      group: SEATA_GROUP
      data-id: seataServer.properties
  registry:
    type: nacos
    preferred-networks: 30.240.*
    nacos:
      application: seata-server
      server-addr: 192.168.210.100:8848
      namespace:
      group: SEATA_GROUP
      cluster: default
```

- **server-addr** 是Nacos宿主机的IP地址，Docker部署别错填 localhost 或Docker容器的IP(172.17. * . *)
- **namespace** nacos命名空间id，不填默认是public命名空间
- **data-id: seataServer.properties** Seata外置文件所处Naocs的Data ID，参考上小节的 **导入配置至 Nacos**
- **group: SEATA_GROUP** 指定注册至nacos注册中心的分组名
- **cluster: default** 指定注册至nacos注册中心的集群名

##### 3. 启动容器

```bash
docker run -d --restart=always \
--name seata-server   \
-p 8091:8091 \
-p 7091:7091 \
-e SEATA_IP=192.168.10.100 \
-v /opt/docker_volume/seata/config:/seata-server/resources \
seataio/seata-server:1.5.2 
```

- **SEATA_IP：** Seata 宿主机IP地址

### minio搭建

#### 创建和启动容器

```bash
docker run -d \
  --restart always \
  -p 9000:9000 \
  -p 9001:9001 \
  --name minio \
  -v /opt/docker_volume/minio/data:/data \
  -v /opt/docker_volume/minio/config:/root/.minio \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=minioadmin" \
  quay.io/minio/minio server /data \
  --console-address ":9001"
```

- -e "MINIO_ROOT_USER=minioadmin" ： MinIO控制台用户名
- -e "MINIO_ROOT_PASSWORD=minioadmin" ：MinIO控制台密码

#### 访问控制台

 **访问MinIO控制台**

控制台地址： [http://192.168.210.100:9001](http://192.168.210.100:9001/)

用户名/密码： minioadmin/minioadmin

### jenkins搭建

```bash
docker run --restart=always \
-di \
--name=jenkins \
-p 8000:8080 \
-v /opt/docker_volume/jenkins:/var/jenkins_home \
jenkins/jenkins:lts
```

### nginx搭建

```bash
docker run --restart=always \
--name nginx \
-p 9527:9527 \
-p 9528:9528 \
-v /opt/docker_volume/nginx/html:/usr/share/nginx/html \
-v /opt/docker_volume/nginx/conf/nginx:/etc/nginx \
-d nginx
```

## 项目启动

### 数据库创建和数据初始化

- **系统数据库**

  进入 `docs/sql` 目录 ， 根据 MySQL 版本选择对应的脚本；

  先执行 `database.sql` 完成数据库的创建；

  再执行 `youlai.sql` 、`mall_*.sql` 完成数据表的创建和数据初始化。

- **Nacos数据库**

  创建名为 `nacos` 的数据库，执行 `middleware/nacos/conf/nacos-mysql.sql` 脚本完成 Nacos 数据库初始化。

- **Seata数据库**

  创建名为 `seata` 的数据库，执行 `docs/seata/seata.sql` 脚本完成 Seata 数据库初始化。

### Naco配置和启动

1. **Nacos配置持久化至MySQL**

   > Nacos默认使用内嵌的derby数据库，如果需要持久化至MySQL做以下调整即可

   修改项目 `middleware/nacos/conf/application.properties` 文件的数据库连接，完整修改示例如下：

   ```properties
   spring.datasource.platform=mysql
   db.num=1
   db.url.0=jdbc:mysql://localhost:3306/nacos?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=UTC
   db.user.0=root
   db.password.0=123456
   ```

2. **导入Nacos配置**

   IDEA 打开命令行终端 Terminal，输入 `cd middleware/nacos/bin` 切换到 Nacos 的 bin 目录，执行 `startup -m standalone` 启动 Nacos 服务；

   打开浏览器，地址栏输入 Nacos 控制台的地址 [http://localhost:8848/nacos ](http://localhost:8848/nacos)；

   输入用户名/密码：nacos/nacos ；

   进入控制台，点击左侧菜单 `配置管理` → `配置列表` 进入列表页面，点击 `导入配置` 选择项目中的 `docs/nacos/DEFAULT_GROUP.zip` 文件。

3. **修改Nacos配置**

   在 Nacos 控制台配置列表选择共享配置 `youlai-common.yaml` 进行编辑，修改 MySQL、Redis、RabbitMQ等中间件信息为您自己本地环境，默认是「有来」线上环境。

4. **修改Nacos配置中心地址**

   批量替换应用的 bootstrap-dev.yml 文件的配置中心地址 `http://c.youlai.tech:8848` →`http://localhost:8848` ，默认是「有来」线上的配置中心地址。

### 微服务启动

- `youlai-gateway` 模块的启动类 GatewayApplication 启动网关；
- `youlai-auth` 模块的启动类 AuthApplication 启动认证中心；
- `youlai-admin` → `admin-boot` 模块的启动类 AdminApplication 启动系统服务；
- 至此完成基础服务的启动，商城服务按需启动，启动方式和 `youlai-admin` 一致；
- 访问接口文档地址测试: [http://localhost:9999/doc.html ](http://localhost:9999/doc.html)。

### 前端启动

1. 本机安装 Node 环境
2. npm install
3. npm run dev
4. 访问 http://localhost:9527

### 移动端Html5启动

1. 下载 `HBuilder X` ;
2. 导入 [mall-app ](https://gitee.com/youlaitech/youlai-mall-weapp)源码至 `HBuilder X`;
3. `Hbuilder X` 工具栏点击 `运行` -> `运行到内置浏览器` 。

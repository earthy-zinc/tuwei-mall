# SpringBoot单体应用部署Dockerfile
FROM openjdk:8-jdk-alpine

# /tmp 目录就会在运行时自动挂载为匿名卷，任何向 /tmp 中写入的信息都不会记录进容器存储层
VOLUME /tmp

COPY youlai-gateway/target/*.jar youlai-gateway.jar
COPY youlai-auth/target/*.jar youlai-auth.jar
COPY youlai-system/system-boot/target/*.jar system-boot.jar
COPY mall-oms/oms-boot/target/*.jar mall-oms.jar
COPY mall-pms/pms-boot/target/*.jar mall-pms.jar
COPY mall-sms/sms-boot/target/*.jar mall-sms.jar
COPY mall-ums/ums-boot/target/*.jar mall-ums.jar

CMD java -jar /youlai-gateway.jar & \
    java -jar /youlai-auth.jar & \
    java -jar /system-boot.jar & \
    java -jar /mall-oms.jar & \
    java -jar /mall-pms.jar & \
    java -jar /mall-sms.jar & \
    java -jar /mall-ums.jar

EXPOSE 9999

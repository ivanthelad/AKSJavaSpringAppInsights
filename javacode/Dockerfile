FROM openjdk:8-jdk-alpine
ARG JAR_FILE=target/*.jar
ARG APP_FILE=applicationinsights-agent-3.4.1.jar
COPY ${JAR_FILE} app.jar
COPY ${APP_FILE} applicationinsights-agent-3.4.1.jar
ENTRYPOINT ["java","-javaagent:applicationinsights-agent-3.4.1.jar","-jar","/app.jar"]
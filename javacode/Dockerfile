FROM  maven:3.6.3-openjdk-11 AS build 
COPY . /app
WORKDIR /app
RUN mvn clean package
##mcr.microsoft.com/openjdk/jdk:17-distroless
# Package stage
FROM mcr.microsoft.com/openjdk/jdk:17-ubuntu
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
#CMD ["-Xmx256m", "-jar", "/app.jar"]
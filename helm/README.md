# AIV Helm Chart quick start guide

## Install dependencies
- Install helm
```
curl https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz -o /tmp/helm-linux-amd64.tar.gz
tar -xf /tmp/helm-linux-amd64.tar.gz -C /tmp
sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm
```

### PostgreSQL helm chart
- Add the Bitnami repository

```
helm repo add bitnami https://charts.bitnami.com/bitnami
```
- Build the PostgreSQL helm chart values file

```sh
cat > values.postgresql.yaml <<EOF
primary:
  initdb:
    scripts:
    postgresql-init.sql: |
      CREATE USER aiv WITH PASSWORD 'aiv_password';
      CREATE DATABASE aiv WITH OWNER aiv ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;
      GRANT ALL PRIVILEGES ON DATABASE aiv TO aiv;

EOF

```

- Install the PostgreSQL helm chart with the values file

```
helm install postgresql bitnami/postgresql -f values.postgresql.yaml
```

### Kafka helm chart

helm repo add bitnami https://charts.bitnami.com/bitnami
- Build helm values
```
cat > helm/values.kafka.yaml << EOF
listeners:
  client:
    protocol: PLAINTEXT
  controller:
    protocol: PLAINTEXT
  interbroker:
    protocol: PLAINTEXT

EOF
```

- Install the Kafka cluster chart with the values file

```
helm install kafka bitnami/kafka -f values.kafka.yaml
```

## Install the AIV helm chart
- Add aiv charts
```
helm repo add aiv-charts https://aiv-code.github.io/docker-aiv/
```

- Build the AIV helm chart values file
```sh
cat > values.aiv.yaml <<EOF
fullnameOverride: aiv
fullnameOverride: "aiv"

replicaCount: 2

volumeMounts:
- mountPath: /var/lib/aiv/repository/econfig/application.yml
  subPath: application.yml
  name: files

- mountPath: /var/lib/aiv/repository/econfig/logback.xml
  subPath: logback.xml
  name: files

files:
  application.yml: |
    server:
      compression:
        enabled: true
        mime-types: application/json, text/html, text/xml, text/plain,text/css, text/javascript, application/javascript, application/octet-stream
        min-response-size: 1024
      servlet:
        context-path: /aiv
      port: 80
    spring:
      autoconfigure:
        exclude: org.springframework.boot.autoconfigure.mongo.MongoAutoConfiguration
      resources:
        static-locations: classpath:/static/,file:///var/lib/aiv/repository/images/
      jackson:
        serialization:
          WRITE_DATES_AS_TIMESTAMPS: false
        time-zone: UTC
      datasource:
        url: jdbc:postgresql://postgresql.default.svc.cluster.local:5432/avi # database for aiv schema
        username: aiv
        password: aiv_password
        driverClassName: org.postgresql.Driver
      datasource1:
        url: jdbc:postgresql://postgresql.default.svc.cluster.local:5432/aiv?currentSchema=security # database for security schema
        username: aiv
        password: aiv_password
        driverClassName: org.postgresql.Driver
      mvc:
        pathmatch:
          matching-strategy: ANT_PATH_MATCHER
      jpa:
        hibernate:
          ddl-auto: update
      liquibase:
       aiv:
         enabled: true
         change-log: classpath:db/changelog/db.changelog-aiv.sql
       security:
         enabled: true
         change-log: classpath:db/changelog/db.changelog-security.sql
      kafka:
        bootstrap-servers: kafka:9092
        consumer:
          group-id: task-consumer-group
          auto-offset-reset: earliest
          key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
          value-deserializer: com.aiv.cluster.MapDeserializer
        producer:
          key-serializer: org.apache.kafka.common.serialization.StringSerializer
          value-serializer: com.aiv.cluster.MapSerializer

    #For JNDI Datasources
    datasources:
      dslist[0]: '{"jndi-name":"jdbc/ActiveIDB","driver-class-name":"org.postgresql.Driver","url":"jdbc:postgresql://postgresql.default.svc.cluster.local:5432/aiv","username":"aiv","password":"aiv_password"}'

    #Application some default values
    # slatKey -> For stoken decryption SecretKey
    # ivspec -> For stoken Iv Spec Key
    # securityClass -> which security class we need to use for authentication and user/roles details
    # isJira -> Are we using Jira authentication or not
    app:
      slatKey: 0123456789abcdef
      ivspec: fedcba9876543210
      imgLocation: /var/lib/aiv/repository/images/
      appLocation: /var/lib/aiv/repository/APP/
      repositoryLocation: /var/lib/aiv/repository
      logDir: /var/log/aiv
      deliveryLocation: /var/lib/aiv/repository/delivery
      database: postgresql
      securityClass: com.security.services.SimpleAuthImpl #com.simple.services.SimpleAuthImpl/com.utility.JiraAuthImpl
      isJira: false
      noofreports: 10
      task:
        kafka:
          retention.ms: 60000
          topic:
            topicName: task-topic       # Name of the Kafka topic
            partitions: 2         # Number of partitions for the topic
            replication-factor:  1
        manager:
          mode: multi  # use "single" if you want to disable Kafka or multi

    #While creating Embed token
    # ekey -> Generating Embed Encrypted insternal token.
    # tokenKey -> For generating Embed authentication token
    embed:
      ekey: ActiveInteigence
      tokenKey: H0WWWrNDCCoVKVPXMSei9/+rDJcLbgkEOXhayw790lY=
      iscustomtoken: false

    logging:
      level:
        liquibase: OFF

    # Token used for MicroServices Internal Authentication
    aiv-internalToken: ActiveIntelligence
    management.metrics.mongo.command.enabled: false
    management.metrics.mongo.connectionpool.enabled: false

  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <springProperty scope="context" name="jsonlogs" source="app.logs.jsonlogs"/>
      <springProperty scope="context" name="showdept" source="app.logs.showdept"/>
      <springProperty scope="context" name="showtraceid" source="app.logs.showtraceid"/>
      <logger name="core" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <logger name="db" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <logger name="data" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <logger name="birt" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <logger name="rest" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <logger name="jasper" level="INFO" additivity="false">
        <appender-ref ref="CONSOLE"/>
      </logger>
      <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
          <layout class="ch.qos.logback.classic.PatternLayout">
              <Pattern>%d %p %c{1} [%t] %m%n</Pattern>
          </layout>
      </appender>
      <root level="INFO">
        <appender-ref ref="CONSOLE"/>
      </root>

    </configuration>

EOF

```
- Install the AIV helm chart with the values file

```sh
helm install aiv aiv-charts/aiv -f values.aiv.yaml
```

# Access the AIV application
- Forward the AIV service port to your local machine
```
kubectl port-forward svc/aiv 8080:80
```

- Access the AIV application in your web browser at `http://localhost:8080/aiv`

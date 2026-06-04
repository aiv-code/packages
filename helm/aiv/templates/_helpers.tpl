{{/*
Expand the name of the chart.
*/}}
{{- define "aiv.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "aiv.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "aiv.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "aiv.labels" -}}
helm.sh/chart: {{ include "aiv.chart" . }}
{{ include "aiv.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "aiv.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aiv.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "aiv.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "aiv.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
,*/}}
{{- define "common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
PostgreSQL primary datasource URL
*/}}
{{- define "aiv.postgresql.url" -}}
{{- if .Values.postgresql.enabled -}}
jdbc:postgresql://{{ .Values.postgresql.host }}:{{ .Values.postgresql.port }}/{{ .Values.postgresql.database }}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL datasource1 URL (security schema)
*/}}
{{- define "aiv.postgresql.datasource1.url" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.datasource1.enabled -}}
jdbc:postgresql://{{ .Values.postgresql.host }}:{{ .Values.postgresql.port }}/{{ .Values.postgresql.database }}?currentSchema={{ .Values.postgresql.datasource1.schema }}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL JNDI configuration JSON
*/}}
{{- define "aiv.postgresql.jndi.config" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.jndi.enabled -}}
{"jndi-name":"{{ .Values.postgresql.jndi.name }}","driver-class-name":"org.postgresql.Driver","url":"{{ include "aiv.postgresql.url" . }}","username":"{{ .Values.postgresql.username }}","password":"{{ .Values.postgresql.password }}"}
{{- end -}}
{{- end -}}

{{/*
Kafka bootstrap servers
*/}}
{{- define "aiv.kafka.bootstrapServers" -}}
{{- if .Values.kafka.enabled -}}
{{ .Values.kafka.bootstrapServers }}
{{- end -}}
{{- end -}}

{{/*
Generate random hex string (16 chars)
*/}}
{{- define "aiv.generateHex" -}}
{{- randAlphaNum 16 | lower -}}
{{- end -}}

{{/*
Generate random base64 token
*/}}
{{- define "aiv.generateToken" -}}
{{- randAlphaNum 32 | b64enc -}}
{{- end -}}

{{/*
Get or generate slatKey
*/}}
{{- define "aiv.slatKey" -}}
{{- if .Values.application.secrets.slatKey -}}
{{ .Values.application.secrets.slatKey }}
{{- else -}}
{{ include "aiv.generateHex" . }}
{{- end -}}
{{- end -}}

{{/*
Get or generate ivspec
*/}}
{{- define "aiv.ivspec" -}}
{{- if .Values.application.secrets.ivspec -}}
{{ .Values.application.secrets.ivspec }}
{{- else -}}
{{ include "aiv.generateHex" . }}
{{- end -}}
{{- end -}}

{{/*
Get or generate internalToken
*/}}
{{- define "aiv.internalToken" -}}
{{- if .Values.application.secrets.internalToken -}}
{{ .Values.application.secrets.internalToken }}
{{- else -}}
{{ include "aiv.generateToken" . }}
{{- end -}}
{{- end -}}

{{/*
Get or generate embedEkey
*/}}
{{- define "aiv.embedEkey" -}}
{{- if .Values.application.secrets.embedEkey -}}
{{ .Values.application.secrets.embedEkey }}
{{- else -}}
{{ randAlphaNum 20 }}
{{- end -}}
{{- end -}}

{{/*
Get or generate embedTokenKey
*/}}
{{- define "aiv.embedTokenKey" -}}
{{- if .Values.application.secrets.embedTokenKey -}}
{{ .Values.application.secrets.embedTokenKey }}
{{- else -}}
{{ include "aiv.generateToken" . }}
{{- end -}}
{{- end -}}
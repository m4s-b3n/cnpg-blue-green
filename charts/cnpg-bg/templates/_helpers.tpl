{{/* Hook image reference — registry is optional */}}
{{- define "cnpg-bg.hookImage" -}}
{{- with .Values.hooks.image -}}
{{- if .registry }}{{ .registry }}/{{ end }}{{ .repository }}:{{ .tag }}
{{- end -}}
{{- end }}

{{/* Database image reference — registry is optional */}}
{{- define "cnpg-bg.databaseImage" -}}
{{- with .Values.database.image -}}
{{- if .registry }}{{ .registry }}/{{ end }}{{ .repository }}:{{ .tag }}
{{- end -}}
{{- end }}

{{/* PgBouncer image reference — registry is optional */}}
{{- define "cnpg-bg.pgbouncerImage" -}}
{{- with .Values.pgbouncer.image -}}
{{- if .registry }}{{ .registry }}/{{ end }}{{ .repository }}:{{ .tag }}
{{- end -}}
{{- end }}

{{/* Chart name */}}
{{- define "cnpg-bg.name" -}}
{{- .Values.database.name }}
{{- end }}

{{/* Blue cluster name */}}
{{- define "cnpg-bg.blue" -}}
{{- printf "%s-blue" .Values.database.name }}
{{- end }}

{{/* Green cluster name */}}
{{- define "cnpg-bg.green" -}}
{{- printf "%s-green" .Values.database.name }}
{{- end }}

{{/* This cluster's name based on mode */}}
{{- define "cnpg-bg.clusterName" -}}
{{- if eq .Values.mode "blue" }}
{{- include "cnpg-bg.blue" . }}
{{- else if eq .Values.mode "green" }}
{{- include "cnpg-bg.green" . }}
{{- end }}
{{- end }}

{{/* The other cluster's name */}}
{{- define "cnpg-bg.otherCluster" -}}
{{- if eq .Values.mode "blue" }}
{{- include "cnpg-bg.green" . }}
{{- else if eq .Values.mode "green" }}
{{- include "cnpg-bg.blue" . }}
{{- end }}
{{- end }}

{{/* Common labels */}}
{{- define "cnpg-bg.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "cnpg-bg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
cnpg-blue-green/database: {{ .Values.database.name }}
cnpg-blue-green/mode: {{ .Values.mode }}
{{- end }}

{{/* Blue RW service FQDN */}}
{{- define "cnpg-bg.blue.rwHost" -}}
{{- printf "%s-blue-rw.%s.svc.cluster.local" .Values.database.name .Release.Namespace }}
{{- end }}

{{/* Green RW service FQDN */}}
{{- define "cnpg-bg.green.rwHost" -}}
{{- printf "%s-green-rw.%s.svc.cluster.local" .Values.database.name .Release.Namespace }}
{{- end }}

{{/* App secret names (overrideable) */}}
{{- define "cnpg-bg.blueAppSecretName" -}}
{{- $default := printf "%s-app-user" .Values.database.name -}}
{{- $credentials := get .Values "credentials" | default dict -}}
{{- $secret := get $credentials "secret" | default dict -}}
{{- get $secret "name" | default $default -}}
{{- end }}

{{- define "cnpg-bg.greenAppSecretName" -}}
{{- include "cnpg-bg.blueAppSecretName" . -}}
{{- end }}

{{- define "cnpg-bg.clusterAppSecretName" -}}
{{- if eq .Values.mode "blue" }}
{{- include "cnpg-bg.blueAppSecretName" . -}}
{{- else if eq .Values.mode "green" }}
{{- include "cnpg-bg.greenAppSecretName" . -}}
{{- end }}
{{- end }}

{{/* Replication secret names (overrideable) */}}
{{- define "cnpg-bg.blueReplicaSecretName" -}}
{{- $default := printf "%s-replica-user" .Values.database.name -}}
{{- $replication := get .Values "replication" | default dict -}}
{{- $secret := get $replication "secret" | default dict -}}
{{- get $secret "name" | default $default -}}
{{- end }}

{{- define "cnpg-bg.greenReplicaSecretName" -}}
{{- include "cnpg-bg.blueReplicaSecretName" . -}}
{{- end }}

{{- define "cnpg-bg.clusterReplicaSecretName" -}}
{{- if eq .Values.mode "blue" }}
{{- include "cnpg-bg.blueReplicaSecretName" . -}}
{{- else if eq .Values.mode "green" }}
{{- include "cnpg-bg.greenReplicaSecretName" . -}}
{{- end }}
{{- end }}

{{/* Secret key overrides used by refs that accept explicit key names */}}
{{- define "cnpg-bg.appPasswordKey" -}}
{{- $credentials := get .Values "credentials" | default dict -}}
{{- $secret := get $credentials "secret" | default dict -}}
{{- $keys := get $secret "keys" | default dict -}}
{{- get $keys "password" | default "password" -}}
{{- end }}

{{- define "cnpg-bg.replicaPasswordKey" -}}
{{- $replication := get .Values "replication" | default dict -}}
{{- $secret := get $replication "secret" | default dict -}}
{{- $keys := get $secret "keys" | default dict -}}
{{- get $keys "password" | default "password" -}}
{{- end }}

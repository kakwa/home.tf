{{- define "technically-blog.middlewareAuthName" -}}
{{ printf "%s-basic-auth" .Release.Name }}
{{- end }}

{{- define "technically-blog.serversTransportName" -}}
{{ printf "%s-transport" .Release.Name }}
{{- end }}

{{- define "technically-blog.middlewareAuthRef" -}}
{{ printf "%s-%s@kubernetescrd" .Release.Namespace (include "technically-blog.middlewareAuthName" .) }}
{{- end }}

{{- define "technically-blog.serversTransportRef" -}}
{{ printf "%s-%s@kubernetescrd" .Release.Namespace (include "technically-blog.serversTransportName" .) }}
{{- end }}

{{- define "technically-blog.dockerconfigjson" -}}
{{- $server := .Values.registryAuth.server -}}
{{- $user := .Values.registryAuth.username -}}
{{- $pass := .Values.registryAuth.password -}}
{{- $auth := printf "%s:%s" $user $pass | b64enc -}}
{{- $entry := dict "username" $user "password" $pass "auth" $auth -}}
{{- dict "auths" (dict $server $entry) | toJson -}}
{{- end }}

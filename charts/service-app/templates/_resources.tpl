{{- define "service-app.rollout" -}}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Release.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
              protocol: TCP
          readinessProbe:
            httpGet:
              path: {{ .Values.probe.path }}
              port: {{ .Values.service.port }}
            initialDelaySeconds: {{ .Values.probe.initialDelaySeconds }}
            periodSeconds: {{ .Values.probe.periodSeconds }}
          {{- if .Values.probe.liveness }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probe.path }}
              port: {{ .Values.service.port }}
            initialDelaySeconds: {{ .Values.probe.livenessInitialDelaySeconds | default 15 }}
            periodSeconds: {{ .Values.probe.periodSeconds }}
          {{- end }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
  strategy:
    canary:
      stableService: {{ .Release.Name }}-stable
      canaryService: {{ .Release.Name }}-canary
      trafficRouting:
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: {{ .Release.Name }}
      steps:
        {{- toYaml .Values.rollout.canary.steps | nindent 8 }}
{{- end -}}

{{- define "service-app.services" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-stable
spec:
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-canary
spec:
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
{{- end -}}

{{- define "service-app.httproute" -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ .Release.Name }}
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: {{ .Values.gateway.name }}
      namespace: {{ .Values.gateway.namespace }}
  hostnames:
    - {{ .Values.hostname }}
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - group: ""
          kind: Service
          name: {{ .Release.Name }}-stable
          port: {{ .Values.service.port }}
          weight: 100
        - group: ""
          kind: Service
          name: {{ .Release.Name }}-canary
          port: {{ .Values.service.port }}
          weight: 0
{{- end -}}

{{- define "service-app.resources" -}}
{{ include "service-app.rollout" . }}
---
{{ include "service-app.services" . }}
---
{{ include "service-app.httproute" . }}
{{- end -}}

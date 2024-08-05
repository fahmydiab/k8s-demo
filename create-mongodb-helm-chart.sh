#!/bin/bash

# Define chart name
CHART_NAME="mongodb"

# Create directory structure
mkdir -p ${CHART_NAME}/templates

# Create Chart.yaml
cat <<EOF > ${CHART_NAME}/Chart.yaml
apiVersion: v2
name: mongodb
description: A Helm chart for MongoDB
type: application
version: 0.1.0
appVersion: "4.4.6"
EOF

# Create values.yaml
cat <<EOF > ${CHART_NAME}/values.yaml
replicaCount: 2

image:
  repository: mongo
  tag: "4.4.6"
  pullPolicy: IfNotPresent

master:
  name: mongo-master
  service:
    type: ClusterIP
    port: 27017

worker:
  name: mongo-worker
  service:
    type: ClusterIP
    port: 27017

persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeName: your-node-name
EOF

# Create templates/_helpers.tpl
cat <<EOF > ${CHART_NAME}/templates/_helpers.tpl
{{- define "mongodb.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}
EOF

# Create templates/master-deployment.yaml
cat <<EOF > ${CHART_NAME}/templates/master-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.master.name }}
  labels:
    app: {{ include "mongodb.fullname" . }}
    tier: master
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ include "mongodb.fullname" . }}
      tier: master
  template:
    metadata:
      labels:
        app: {{ include "mongodb.fullname" . }}
        tier: master
    spec:
      containers:
        - name: mongo
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.master.service.port }}
          volumeMounts:
            - name: mongo-persistent-storage
              mountPath: /data/db
      volumes:
        - name: mongo-persistent-storage
          persistentVolumeClaim:
            claimName: mongo-pv-claim
EOF

# Create templates/worker-deployment.yaml
cat <<EOF > ${CHART_NAME}/templates/worker-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.worker.name }}
  labels:
    app: {{ include "mongodb.fullname" . }}
    tier: worker
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "mongodb.fullname" . }}
      tier: worker
  template:
    metadata:
      labels:
        app: {{ include "mongodb.fullname" . }}
        tier: worker
    spec:
      containers:
        - name: mongo
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.worker.service.port }}
          args: ["--replSet", "rs0"]
          volumeMounts:
            - name: mongo-persistent-storage
              mountPath: /data/db
      volumes:
        - name: mongo-persistent-storage
          persistentVolumeClaim:
            claimName: mongo-pv-claim
EOF

# Create templates/master-service.yaml
cat <<EOF > ${CHART_NAME}/templates/master-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.master.name }}
spec:
  type: {{ .Values.master.service.type }}
  ports:
    - port: {{ .Values.master.service.port }}
  selector:
    app: {{ include "mongodb.fullname" . }}
    tier: master
EOF

# Create templates/worker-service.yaml
cat <<EOF > ${CHART_NAME}/templates/worker-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.worker.name }}
spec:
  type: {{ .Values.worker.service.type }}
  ports:
    - port: {{ .Values.worker.service.port }}
  selector:
    app: {{ include "mongodb.fullname" . }}
    tier: worker
EOF

# Create templates/pvc.yaml
cat <<EOF > ${CHART_NAME}/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pv-claim
spec:
  storageClassName: {{ .Values.persistence.storageClassName }}
  accessModes:
    - {{ .Values.persistence.accessModes | join "," }}
  resources:
    requests:
      storage: {{ .Values.persistence.size }}
EOF

# Create templates/pv-local.yaml
cat <<EOF > ${CHART_NAME}/templates/pv-local.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ .Release.Name }}-pv-local
spec:
  capacity:
    storage: {{ .Values.persistence.size }}
  accessModes:
    - {{ .Values.persistence.accessModes | join "," }}
  storageClassName: {{ .Values.persistence.storageClassName }}
  local:
    path: {{ .Values.persistence.local.path }}
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - {{ .Values.persistence.nodeName }}
EOF

echo "Helm chart structure for MongoDB has been created."

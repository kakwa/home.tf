# Generated for init-traefik.sh — Traefik as cluster ingress (Ingress + IngressRoute CRD).
ingressClass:
  enabled: true
  isDefaultClass: true

service:
  spec:
    type: ${service_type}

%{ if service_type == "NodePort" ~}
ports:
  web:
    nodePort: ${web_node_port}
  websecure:
    nodePort: ${websecure_node_port}
%{ endif ~}

providers:
  kubernetesCRD:
    enabled: true
  kubernetesIngress:
    enabled: true

deployment:
  replicas: 1

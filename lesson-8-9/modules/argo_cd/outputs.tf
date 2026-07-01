# Argo CD is exposed via a LoadBalancer, and its first-login admin password is
# stored in the 'argocd-initial-admin-secret' Secret. We output ready-to-run
# kubectl commands rather than reading those during apply.

output "argocd_url_command" {
  description = "Prints the public Argo CD address (may take 1-3 min for AWS to assign it)."
  value       = "kubectl -n ${var.namespace} get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo"
}

output "admin_password_command" {
  description = "Prints the Argo CD 'admin' password (username is 'admin')."
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode; echo"
}

output "namespace" {
  description = "Namespace Argo CD was installed into."
  value       = var.namespace
}

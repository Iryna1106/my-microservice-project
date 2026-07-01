# Jenkins is exposed via a LoadBalancer Service, and its admin password lives in
# a Secret. Rather than read those during apply (which can be racy right after
# install), we output ready-to-run kubectl commands you can paste afterwards.

output "jenkins_url_command" {
  description = "Prints the public Jenkins address (may take 1-3 min for AWS to assign it)."
  value       = "kubectl -n ${var.namespace} get svc jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo"
}

output "admin_password_command" {
  description = "Prints the auto-generated Jenkins 'admin' password."
  value       = "kubectl -n ${var.namespace} get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 --decode; echo"
}

output "namespace" {
  description = "Namespace Jenkins was installed into."
  value       = var.namespace
}

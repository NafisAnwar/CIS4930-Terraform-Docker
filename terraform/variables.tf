variable "application_port" {
  description = "Host port used to access the Flask application."
  type        = number
  default     = 8081

  validation {
    condition     = var.application_port >= 1024 && var.application_port <= 65535
    error_message = "The application port must be between 1024 and 65535."
  }
}

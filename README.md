# hetzner-nomad-consul

This module allows you to create a manually-scalable high-availability nomad cluster on Hetzner Cloud.
You only need to provide a API token as variable and a default cluster with 3 servers and 1 client will be created.

## Advanced Usage

The module is mainly addressed to people who want to test the technology running terraform on their local PC, but it can be used in professional workflows as well.

### Usage in CI/CD pipelines

The module creates on startup the CA files as well as a master key for the consul communication.
Generally the folder of these files is created on the initial apply and destroy after a terraform destroy.
Nevertheless there is a condition that checks if these files are already in place during the first apply and dependent on this it will create or will not create new ones. 
In addition to this, it is required that you create dummy key pairs for the already existing server and clients. The files can be empty it is just a requirement for them to exist as terraform keeps their reference in the state and tries to read it on plan/destroy/apply.


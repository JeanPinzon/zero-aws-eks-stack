## Guidelines & Style Convention Summary

- All Terraform configuration should be formatted with `terraform fmt` before being accepted into this repository.
- This repository is Terraform version >= 0.12, as such, leverage features from this release whenever possible.
    See https://www.terraform.io/upgrade-guides/0-12.html for more information.
- Leverage community-maintained Terraform modules whenever possible.
- Attempt to minimize duplication whenever possible, but only within reason -- sometimes duplication is an acceptable solution.
- Follow style conventions described in `docs/guide.pdf` whenever possible.
- Whenever possible, inject resources down versus referencing resources across modules. This has been made easier with new features in v0.12.
- Whenever possible, define the types of variables.

### Module Conventions

- All modules should contain the following:

    `README.md`: A description of the module.
    `main.tf`: Module entrypoint where instantiation of resources happens.
    `variables.tf`: Module variables.
    `outputs.tf`: Output values (optional).
    `files/`: Any / all files required by the module.

- All module variables must have a description.
- Again, leverage community-maintained Terraform modules whenever possible.
- Avoid writing a module that is simply a wrapper of a Terraform resource unless absolutely necessary.

### Environment Conventions

- All environments should contain the following:

    `main.tf`: Toplevel terraform configuration file that instantiates the `environment` module.

- Configuration should be pushed "top->down" from the `environment` module to it's submodules.

### The Environment Module

- The `environment` module can be considered the top-level module, all other modules are imported from this module.
- Environment-specific variables should be exposed via the `variables.tf` file in this module, where they will be set from within the appropriate environment in the `environments/` directory.
- The `environment` module contains the following:

    `main.tf`: Module entrypoint where instantiation of resources happens.
    `backend.tf`: Terraform remote state configuration.
    `provider.tf`: Provider configuration.
    `variables.tf`: Environment-specific variables are desclared here.
    `versions.tf`: Terraform version information.
    `files/`: (DEPRECATED)

## Directory Structure

```
    README.md
    environments/
        production/
            main.tf
        staging/
            main.tf
        development/
            main.tf
    docs/
        guide.pdf
    modules/
        environment/
            ...
        <module-a>/
            files/
            scripts/
            main.tf
            outputs.tf
            variables.tf
        <module-n>/
        ...
```

## AWS Guidelines

- TODO: Identity/Access Management (IAM) Guidelines

## Kubernetes Guidelines

- When to use the Terraform Kuberenetes Provider and when to use manifests?

    - Use the Terraform Kubernetes Provider (`provider "kubernetes"`) whenever you are provisioning a resource that could be considered relatively static (think Ingress, RoleBinding, CluterRoleBinding, etc).

    - Use conventional Kubernetes manifests / `kubectl` when provisioning resouirces that could be considered dynamic (think Deployments).

## Application

 1. Set up a profile for your project with your credentials in a specific profile in `~/.aws/credentials` and then export the following env var:
 `export AWS_PROFILE=<project_name>`

 2. Run the following from the appropriate environment directory under `environments/`:

 ```
 environment/development$ terraform init
 environment/development$ terraform plan
 ```

## To use kubectl with the created EKS cluster:

 Exchange your aws credentials for kubernetes credentials.
 This will add a new context to your kubeconfig.
 `aws eks update-kubeconfig --name <cluster name> --region <aws region>`



## Upgrading an EKS Cluster

Occasionally you may need to upgrade an EKS cluster. This is usually a pretty painless process, and there’s a ton of documentation online about it.

As part of this process you will need to upgrade the cluster itself, and some core components. Kubernetes has various applications that run as deployments or daemonsets in the `kube-system` namespace like `coredns`, `kube-proxy` and the AWS VPC CNI provider called `aws-node`.

This document has great instructions on upgrading all of the different pieces, including listing the appropriate versions of the core components for each version of Kubernetes.

[https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html)

When doing this from terraform you should be able to go into the tf and change the version of the cluster. It should start the upgrade process, rather than tearing down the cluster and rebuilding it. This will make the cluster inaccessible through the AWS console for about 20 minutes, ***though everything in the cluster should continue to work normally, serve traffic, etc.***

The process should be:

- Update the API version number in terraform
- Update the AMI for the ASG to the AMI for the corresponding version of EKS in eks.tf and apply terraform
    - See this page: [https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
    - This should update the worker group, but not affect any of the running nodes
- Update any core components if necessary, as mentioned in the aws update-cluster documentation
- Run terraform apply
- Drain and remove the old nodes from the cluster. New ones will come up in their place with the new AMI
    - `kubectl get nodes`
    - `kubectl cordon <node name>`
    - `kubectl drain <node name>`
    - Then terminate the instance in AWS Console
- (The cordon command stops new pods from being scheduled on a node, the drain command evicts all pods from a node and schedules them elsewhere.)
- Do the drain/delete process with one node at a time. Wait for a new node to be available before running the process on a second one. This will prevent any traffic from being lost.

Done!
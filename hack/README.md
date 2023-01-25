## Hack

hack folder contains resources for hacking.

Apply a `ytt` parameterized Tekton Pipeline for running your tests as follows:
```bash
ytt -f https://raw.githubusercontent.com/atmandhol/tap-nsp-gitops/main/hack/parameterized-tekton-pipeline.yaml -v image="gradle" -v cmd="./mvnw test" |
 kubectl apply -f -
```
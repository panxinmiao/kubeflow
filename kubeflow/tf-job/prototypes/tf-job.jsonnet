// @apiVersion 0.1
// @name io.ksonnet.pkg.tf-job
// @description A TensorFlow job (could be training or evaluation).
// @shortDescription A TensorFlow job.
// @param name string Name to give to each of the components
// @optionalParam namespace string null Namespace to use for the components. It is automatically inherited from the environment if not set.
// @optionalParam args string null Comma separated list of arguments to pass to the job
// @optionalParam image string null The docker image to use for the job.
// @optionalParam image_gpu string null The docker image to use when using GPUs.
// @optionalParam image_pull_secrets string null Comma-delimited list of secret names to use credentials in pulling your docker images.
// @optionalParam num_masters number 1 The number of masters to use
// @optionalParam num_ps number 0 The number of ps to use
// @optionalParam num_workers number 0 The number of workers to use
// @optionalParam num_gpus number 0 The number of GPUs to attach to workers.
// @optionalParam gluster_ep string glusterfs-cluster The glusterfs endpoint.
// @optionalParam gluster_path string null The glusterfs volume path.

// TODO(https://github.com/ksonnet/ksonnet/issues/235): ks param set args won't work if the arg starts with "--".

local k = import "k.libsonnet";
local tfJob = import "kubeflow/tf-job/tf-job.libsonnet";
// updatedParams uses the environment namespace if
// the namespace parameter is not explicitly set
local updatedParams = params {
  namespace: if params.namespace == "null" then env.namespace else params.namespace,
};

local name = import "param://name";
local namespace = updatedParams.namespace;

local argsParam = import "param://args";
local args =
  if argsParam == "null" then
    []
  else
    std.split(argsParam, ",");

local image = import "param://image";
local imageGpu = import "param://image_gpu";
local imagePullSecrets = import "param://image_pull_secrets";
local numMasters = import "param://num_masters";
local numPs = import "param://num_ps";
local numWorkers = import "param://num_workers";
local numGpus = import "param://num_gpus";
local glusterEp = import "param://gluster_ep";
local glusterPath = import "param://gluster_path";

local terminationPolicy = if numMasters == 1 then
  tfJob.parts.tfJobTerminationPolicy("MASTER", 0)
else
  tfJob.parts.tfJobTerminationPolicy("WORKER", 0);

local workerSpec = if numGpus > 0 then
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, imageGpu, glusterEp, glusterPath, imagePullSecrets, numGpus)
else
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, image, glusterEp, glusterPath, imagePullSecrets);
  
local masterSpec = if numGpus > 0 then
  tfJob.parts.tfJobReplica("MASTER", numMasters, args, imageGpu, glusterEp, glusterPath, imagePullSecrets, numGpus)
else
  tfJob.parts.tfJobReplica("MASTER", numMasters, args, image, glusterEp, glusterPath, imagePullSecrets);

std.prune(k.core.v1.list.new([
  tfJob.parts.tfJob(
    name, 
    namespace, 
    [
      masterSpec,
      workerSpec,
      tfJob.parts.tfJobReplica("PS", numPs, args, image, glusterEp, glusterPath, imagePullSecrets),
    ],
    terminationPolicy
  ),
]))

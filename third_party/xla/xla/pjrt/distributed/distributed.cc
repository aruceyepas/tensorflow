/* Copyright 2020 The OpenXLA Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "xla/pjrt/distributed/distributed.h"

#include <memory>
#include <string>

#include "grpcpp/channel.h"
#include "grpcpp/create_channel.h"
#include "xla/pjrt/distributed/client.h"
#include "xla/pjrt/distributed/service.h"
#include "xla/statusor.h"
#include "tsl/platform/grpc_credentials.h"

namespace xla {

// In OSS, insecure credentials are used as default.
constexpr bool kVerifySecureCredentials = false;

StatusOr<std::unique_ptr<DistributedRuntimeService>>
GetDistributedRuntimeService(std::string address,
                             const CoordinationServiceImpl::Options& options) {
  return DistributedRuntimeService::Get(
      address, tsl::GetServerCredentials(kVerifySecureCredentials), options);
}

std::shared_ptr<DistributedRuntimeClient> GetDistributedRuntimeClient(
    std::string address, const DistributedRuntimeClient::Options& options) {
  std::shared_ptr<grpc::Channel> channel = grpc::CreateChannel(
      address, tsl::GetClientCredentials(kVerifySecureCredentials));
  return GetDistributedRuntimeClient(channel, options);
}

}  // namespace xla

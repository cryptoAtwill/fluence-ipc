// Copyright 2022-2023 Protocol Labs
// SPDX-License-Identifier: MIT
//! Get the chain head of the subnet

use crate::server::handlers::manager::check_subnet;
use crate::server::handlers::manager::subnet::SubnetManagerPool;
use crate::server::JsonRPCRequestHandler;
use anyhow::anyhow;
use async_trait::async_trait;
use fvm_shared::clock::ChainEpoch;
use ipc_sdk::subnet_id::SubnetID;
use serde::{Deserialize, Serialize};
use std::str::FromStr;
use std::sync::Arc;

#[derive(Debug, Serialize, Deserialize)]
pub struct BlockHashParams {
    pub subnet_id: String,
    pub height: ChainEpoch,
}

/// The create subnet json rpc method handler.
pub(crate) struct BlockHashHandler {
    pool: Arc<SubnetManagerPool>,
}

impl BlockHashHandler {
    pub(crate) fn new(pool: Arc<SubnetManagerPool>) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl JsonRPCRequestHandler for BlockHashHandler {
    type Request = BlockHashParams;
    type Response = Vec<u8>;

    async fn handle(&self, request: Self::Request) -> anyhow::Result<Self::Response> {
        let subnet = SubnetID::from_str(&request.subnet_id)?;
        let conn = match self.pool.get(&subnet) {
            None => return Err(anyhow!("target parent subnet not found")),
            Some(conn) => conn,
        };

        let subnet_config = conn.subnet();
        check_subnet(subnet_config)?;

        conn.manager().get_block_hash(request.height).await
    }
}

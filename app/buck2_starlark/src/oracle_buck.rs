/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under both the MIT license found in the
 * LICENSE-MIT file in the root directory of this source tree and the Apache
 * License, Version 2.0 found in the LICENSE-APACHE file in the root directory
 * of this source tree.
 */

use std::sync::Arc;

use starlark::docs::get_registered_starlark_docs;
use starlark::environment::Globals;
use starlark::typing::*;

pub(crate) fn oracle_buck(globals: &Globals) -> Arc<dyn TypingOracle + Send + Sync> {
    let registered_docs = get_registered_starlark_docs();
    let mut docs = OracleDocs::new();
    docs.add_module(&globals.documentation());
    docs.add_docs(&registered_docs);

    let mut docs2 = OracleDocs::new();
    docs2.add_docs(&registered_docs);

    Arc::new(OracleSeq(vec![
        Box::new(CustomBuck) as Box<dyn TypingOracle + Send + Sync>,
        Box::new(docs),
        Box::new(AddErrors(docs2)),
    ]))
}

struct CustomBuck;

impl TypingOracle for CustomBuck {
    fn subtype(&self, require: &TyName, got: &TyName) -> bool {
        match require.as_str() {
            "provider" => got.as_str().ends_with("Info"),
            _ => false,
        }
    }
}

struct AddErrors(OracleDocs);

impl TypingOracle for AddErrors {
    fn attribute(&self, ty: &TyName, _attr: &str) -> Option<Result<Ty, ()>> {
        if self.0.known_object(ty.as_str()) {
            Some(Err(()))
        } else {
            None
        }
    }
    fn as_function(&self, _ty: &TyName) -> Option<Result<TyFunction, ()>> {
        Some(Err(()))
    }
}

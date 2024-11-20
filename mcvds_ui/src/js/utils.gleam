//import gleam/option.{type Option}

@external(javascript, "./utils_ffi.mjs", "origin")
pub fn origin() -> String

@external(javascript, "./utils_ffi.mjs", "localStorageSetItem")
pub fn local_storage_set_item(key: String, value: String) -> Nil

@external(javascript, "./utils_ffi.mjs", "localStorageGetItem")
pub fn local_storage_get_item(key: String) -> Result(String, Nil)

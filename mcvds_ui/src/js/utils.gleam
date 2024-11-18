//import gleam/option.{type Option}

@external(javascript, "./utils.mts", "origin")
pub fn origin() -> String

@external(javascript, "./utils.mts", "localStorageSetItem")
pub fn local_storage_set_item(key: String, value: String) -> Nil

@external(javascript, "./utils.mts", "localStorageGetItem")
pub fn local_storage_get_item(key: String) -> Result(String, Nil)

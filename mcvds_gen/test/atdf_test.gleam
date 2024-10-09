import atdf
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn first_replace_test() {
  atdf.first_replace([1, 2, 3], fn(i) {
    case i {
      2 -> Ok(666)
      _ -> Error(Nil)
    }
  })
  |> should.equal(Ok([1, 666, 3]))
}
//pub fn test_xmerl_scan_string() {
//  let x = xmerl.xmerl_scan_string("<div>Hello</div>")
//  io.debug(x)
//}

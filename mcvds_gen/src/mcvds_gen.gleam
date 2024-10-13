import atdf
import gleam/io

pub fn main() {
  io.println("Hello from mcvds!")
  case atdf.parse_atdf("./tmp/ATtiny814.atdf") {
    Ok(changeit) -> case atdf.export_atdf(changeit) {
      Ok(..) -> io.println("Done")
      Error(error) -> { io.debug(error) Nil}
    }
    Error(error) -> { io.debug(error) Nil}
  }
}

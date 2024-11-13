import gleam/json
import gleam/option.{Some}
import gleeunit
import gleeunit/should
import mcvds_coders
import mcvds_types as t

pub fn main() {
  gleeunit.main()
}

pub fn atdf_test() {
  let atdf =
    t.Atdf(
      "Atdf",
      [
        t.Device("architecture", "family", "name", [
          t.ModuleReference("id", "name", [
            t.ModuleInstance(
              "name",
              [
                t.InstanceRegisterGroup(
                  Some("address space"),
                  "name",
                  Some("name_in"),
                  123,
                ),
              ],
              [t.Signal(Some("Field"), "function", "group", Some(3), "pad")],
            ),
          ]),
        ]),
      ],
      [
        t.Module("caption", "id", "name", [
          t.RegisterGroup("caption", "name", 5, [
            t.Register("caption", Some(2), "name", 34, t.Read, 3, [
              t.Bitfield("caption", 5, "name", t.Write, Some("values")),
            ]),
          ]),
        ]),
      ],
      [t.Pinout(t.SOIC14, [t.Pin("pad", 3)])],
    )

  should.equal(
    atdf
      |> mcvds_coders.atdf_encoder()
      |> json.to_string()
      |> json.decode(mcvds_coders.atdf_decoder()),
    Ok(atdf),
  )
}

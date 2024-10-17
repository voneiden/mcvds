import gleam/dynamic
import gleam/fetch
import gleam/http/request
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import js/utils
import lustre
import lustre/attribute.{class}
import lustre/effect
import lustre/element.{text}
import lustre/element/html.{div}
import mcvds_coders
import mcvds_types

type Msg {
  ManifestResponse(Result(mcvds_types.Manifest, FetchOrDecodeError))
  AtdfResponse(Result(mcvds_types.Atdf, FetchOrDecodeError))
}

type Model {
  Model(
    atdf: Option(Result(mcvds_types.Atdf, FetchOrDecodeError)),
    manifest: Option(Result(mcvds_types.Manifest, FetchOrDecodeError)),
    error: Option(String),
  )
}

type FetchOrDecodeError {
  FetchError(fetch.FetchError)
  DecodeErrors(dynamic.DecodeErrors)
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) {
  #(
    Model(atdf: None, manifest: None, error: None),
    effect.batch([get_manifest(), get_atdf("ATtiny814.json")]),
  )
}

fn update(model: Model, msg: Msg) {
  let model = case msg {
    ManifestResponse(manifest) -> Model(..model, manifest: Some(manifest))
    AtdfResponse(atdf) -> Model(..model, atdf: Some(atdf))
  }
  #(model, effect.none())
}

fn view(model: Model) {
  case model.manifest {
    Some(Ok(manifest)) -> main_view(model, manifest)
    Some(Error(error)) -> text("Oh fok: " <> string.inspect(error))
    None -> text("Hold up")
  }
}

fn main_view(model: Model, manifest: mcvds_types.Manifest) {
  div([class("flex flex-col h-full")], [
    div([class("flex grow")], [
      div([class("w-60 bg-amber-700")], [text("sidebar")]),
      div([class("grow bg-cyan-500")], [text("chip view")]),
    ]),
    div([class("flex grow")], [
      div([class("grow bg-pink-200")], [text("reg view")]),
      div([class("grow bg-fuchsia-600")], [text("doc view")]),
    ]),
  ])
}

fn to_wrapped_fetch_error() {
  promise.map(_, result.map_error(_, fn(e) { FetchError(e) }))
}

fn to_wrapped_decode_errors() {
  promise.map(_, result.map_error(_, fn(e) { DecodeErrors(e) }))
}

fn get_manifest() {
  effect.from(fn(dispatch) {
    let response = {
      let assert Ok(req) =
        request.to(utils.origin() <> "/priv/static/defs/manifest.json")
      use resp <- promise.try_await(
        fetch.send(req)
        |> to_wrapped_fetch_error(),
      )
      use resp <- promise.try_await(
        fetch.read_json_body(resp) |> to_wrapped_fetch_error(),
      )

      use manifest <- promise.try_await(
        mcvds_coders.manifest_decoder()(resp.body)
        |> promise.resolve
        |> to_wrapped_decode_errors(),
      )

      promise.resolve(Ok(manifest))
    }
    promise.await(response, fn(result) {
      dispatch(ManifestResponse(result))
      promise.resolve(Nil)
    })
    Nil
  })
}

fn get_atdf(name) {
  effect.from(fn(dispatch) {
    let response = {
      let assert Ok(req) =
        request.to(utils.origin() <> "/priv/static/defs/" <> name)
      use resp <- promise.try_await(
        fetch.send(req)
        |> to_wrapped_fetch_error(),
      )
      use resp <- promise.try_await(
        fetch.read_json_body(resp) |> to_wrapped_fetch_error(),
      )

      use manifest <- promise.try_await(
        mcvds_coders.atdf_decoder()(resp.body)
        |> promise.resolve
        |> to_wrapped_decode_errors(),
      )

      promise.resolve(Ok(manifest))
    }
    promise.await(response, fn(result) {
      dispatch(AtdfResponse(result))
      promise.resolve(Nil)
    })
    Nil
  })
}

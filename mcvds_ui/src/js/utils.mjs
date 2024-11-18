import { Ok, Error } from "../gleam.mjs";

export function origin() {
  return window.location.origin;
}

export function localStorageSetItem(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch (e) {
    console.error("Failed to localStorage.setItem", e);
  }
}

export function localStorageGetItem(key) {
  try {
    const value = localStorage.getItem(key);
    if (value) {
      return new Ok(value)
    }
    return new Error(null);
  } catch (e) {
    console.error("Failed to localStorage.getItem", e);
    return new Error(null);
  }
}
/** Postmark merge vars — keeps literal `{{key}}` in exported HTML (JSX `{` + `{{` breaks). */
export function pm(key: string) {
  return `{{${key}}}`;
}

import { ajax } from "discourse/lib/ajax";

// Step one of publishing, for a first release and a new version alike: the
// server inspects the package and answers with what it found.
export async function stagePackage(file) {
  const body = new FormData();
  body.append("file", file);
  const result = await ajax("/pyrite/registry/packages.json", {
    type: "POST",
    data: body,
    processData: false,
    contentType: false,
  });
  return result.package;
}

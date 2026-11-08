import { module, test } from "qunit";
import {
  buildDeepLink,
  packageUrl,
  requiresAcknowledgement,
} from "discourse/plugins/discourse-pyrite-ide-extensions/discourse/lib/pyrite-deep-link";

module("Unit | Utility | pyrite-deep-link", function () {
  test("buildDeepLink encodes the id, version and origin", function (assert) {
    const link = buildDeepLink({
      extId: "com.example.hello",
      version: "1.2.0-beta.1",
      origin: "https://forum.example/sub",
    });

    assert.strictEqual(
      link,
      "pyride://plugin/install?id=com.example.hello&version=1.2.0-beta.1&origin=https%3A%2F%2Fforum.example%2Fsub"
    );
  });

  test("buildDeepLink encodes a scoped plugin id", function (assert) {
    const link = buildDeepLink({
      extId: "@my-org/hello.plugin",
      version: "1.0.0",
      origin: "https://forum.example",
    });

    assert.strictEqual(
      link,
      "pyride://plugin/install?id=%40my-org%2Fhello.plugin&version=1.0.0&origin=https%3A%2F%2Fforum.example"
    );
  });

  test("packageUrl points at the requested package format", function (assert) {
    assert.strictEqual(
      packageUrl({
        origin: "https://forum.example",
        extId: "com.example.hello",
        version: "1.2.0",
        format: "pyrix",
      }),
      "https://forum.example/pyrite/api/v1/extensions/com.example.hello/versions/1.2.0/package.pyrix"
    );
  });

  test("requiresAcknowledgement only applies to high and critical advisories", function (assert) {
    const advisory = (severity) => ({ level: "advisory", severity });

    assert.true(requiresAcknowledgement(advisory("high")));
    assert.true(requiresAcknowledgement(advisory("critical")));
    assert.false(requiresAcknowledgement(advisory("moderate")));
    assert.false(requiresAcknowledgement(advisory("low")));
    assert.false(requiresAcknowledgement({ level: "deprecated" }));
    assert.false(requiresAcknowledgement(undefined));
  });
});

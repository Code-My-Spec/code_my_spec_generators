# CodeMySpecGenerators

Generators for [Code My Spec](https://github.com/Code-My-Spec) applications. Provides
`mix cms_gen.*` tasks that scaffold accounts, integrations, and related modules
into a host Phoenix application.

## Installation

Add `code_my_spec_generators` to your Phoenix app's `deps` in `mix.exs`:

```elixir
def deps do
  [
    {:code_my_spec_generators, "~> 0.1", only: :dev, runtime: false}
  ]
end
```

Then run `mix deps.get`.

## Available tasks

| Task | Description |
| --- | --- |
| `mix cms_gen.accounts` | Accounts, members, and invitations scaffolding |
| `mix cms_gen.content` | Published content context (single-tenant) for deploying/serving content |
| `mix cms_gen.integrations` | OAuth integrations context and LiveViews |
| `mix cms_gen.integration_provider` | A single OAuth provider module (github, google, facebook, quickbooks, codemyspec) |
| `mix cms_gen.support_widget` | Embeddable support widget — live chat + "report a problem", over one deploy-key socket |
| `mix cms_gen.feedback_widget` | **Deprecated** — feedback-only widget; use `cms_gen.support_widget` |

Run any task with `--help` style inspection by opening the module docs, or see
the [hex docs](https://hexdocs.pm/code_my_spec_generators).

## License

MIT — see [LICENSE](LICENSE).

package PropertyManager::Routes::Docs;

use strict;
use warnings;
use Dancer2 appname => 'PropertyManager';
use File::Slurp;
use FindBin;

# Reset any prefix from previously loaded modules
prefix undef;

=head1 NAME

PropertyManager::Routes::Docs - API Documentation routes

=head1 DESCRIPTION

Serves OpenAPI/Swagger documentation and Swagger UI.

=head1 ROUTES

=over 4

=item GET /api/docs - Swagger UI

=item GET /api/docs/openapi.yaml - OpenAPI specification

=item GET /api/docs/openapi.json - OpenAPI specification (JSON)

=back

=cut

# Swagger UI HTML (using CDN)
my $swagger_ui_html = <<'HTML';
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PropertyManager API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    <style>
        html { box-sizing: border-box; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; background: #fafafa; }
        .swagger-ui .topbar { display: none; }
        .swagger-ui .info { margin: 20px 0; }
        .swagger-ui .info .title { font-size: 2em; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            SwaggerUIBundle({
                url: "/api/docs/openapi.yaml",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                persistAuthorization: true,
                tryItOutEnabled: true
            });
        };
    </script>
</body>
</html>
HTML

# Serve Swagger UI
get '/api/docs' => sub {
    send_as html => $swagger_ui_html;
};

# Also serve at /docs for convenience
get '/docs' => sub {
    send_as html => $swagger_ui_html;
};

# Serve OpenAPI spec (YAML)
get '/api/docs/openapi.yaml' => sub {
    my $spec_path = config->{appdir} . '/public/openapi.yaml';

    unless (-f $spec_path) {
        status 404;
        return { success => 0, error => 'OpenAPI specification not found' };
    }

    my $content = read_file($spec_path);

    send_as plain => $content, { content_type => 'application/x-yaml' };
};

# Serve OpenAPI spec (JSON) - converted from YAML
get '/api/docs/openapi.json' => sub {
    my $spec_path = config->{appdir} . '/public/openapi.yaml';

    unless (-f $spec_path) {
        status 404;
        return { success => 0, error => 'OpenAPI specification not found' };
    }

    require YAML::XS;
    my $yaml_content = read_file($spec_path);
    my $spec = YAML::XS::Load($yaml_content);

    return $spec;  # Will be serialized as JSON
};

1;

__END__

=head1 USAGE

Access the API documentation at:

  http://localhost:5000/api/docs
  http://localhost:5000/docs

The OpenAPI specification is available at:

  http://localhost:5000/api/docs/openapi.yaml (YAML format)
  http://localhost:5000/api/docs/openapi.json (JSON format)

=head1 SWAGGER UI FEATURES

The Swagger UI interface provides:

- Interactive API explorer
- Try it out functionality for testing endpoints
- Authentication support (enter JWT token)
- Request/response examples
- Schema documentation

=head1 AUTHOR

Property Management System

=cut

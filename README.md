# Statamic Application Template

A production-ready Statamic CMS template for Quant Cloud, featuring PHP 8.4, Apache with mod_php, and flat-file content storage.

[![Deploy to Quant](https://www.quantcdn.io/img/quant-deploy-btn-sml.svg)](https://dashboard.quantcdn.io/deploy/step-one?template=app-statamic)

## Features

- **Statamic 5** - The radically different flat-file CMS built on Laravel
- **PHP 8.4** with common extensions (GD, PDO, BCMath, EXIF, etc.)
- **Apache + mod_php** - Simple single-container setup
- **Flat-file by default** - No database required
- **Composer** for dependency management
- **Docker & Docker Compose** for containerization
- **Persistent storage** for content, users, and storage directories
- **Quant integration** ready out of the box:
  - Client IP handling via `Quant-Client-IP` header
  - Host header override for `Quant-Orig-Host`
  - SMTP relay support for email delivery
  - UID/GID 1000 mapping for EFS compatibility
- **Logging to stdout/stderr** for Docker best practices

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Git

### Local Development

1. Clone this template:
   ```bash
   git clone <your-repo-url> my-statamic-app
   cd my-statamic-app
   ```

2. Copy and configure environment variables:
   ```bash
   cp docker-compose.override.yml.example docker-compose.override.yml
   ```

   Edit `docker-compose.override.yml` to set your local environment variables, especially:
   - `APP_KEY` - Generate with `docker-compose exec statamic php artisan key:generate`

3. Start the application:
   ```bash
   docker-compose up -d
   ```

4. Generate application key:
   ```bash
   docker-compose exec statamic php artisan key:generate
   ```

5. Create your first user:
   ```bash
   docker-compose exec statamic php please make:user
   ```

6. Access your application at `http://localhost`
7. Access the control panel at `http://localhost/cp`

## Configuration

### Environment Variables

Key environment variables you should configure:

#### Statamic/Laravel Configuration
- `APP_KEY` - Application encryption key (required)
- `APP_ENV` - Application environment (default: production)
- `APP_DEBUG` - Enable debug mode (default: false)
- `APP_URL` - Application URL
- `STATAMIC_LICENSE_KEY` - Your Statamic license key (for Pro features)
- `STATAMIC_STACHE_WATCHER` - Enable file watching for development (default: false)

#### Logging Configuration
- `LOG_CHANNEL` - Logging channel (default: stderr for Docker)
- `LOG_LEVEL` - Log level (default: error)

#### Cache Configuration
- `CACHE_DRIVER` - Cache driver (default: file)
- `SESSION_DRIVER` - Session driver (default: file)
- `QUEUE_CONNECTION` - Queue driver (default: sync)

#### SMTP Configuration
- `QUANT_SMTP_RELAY_ENABLED` - Enable Postfix SMTP relay (default: false)
- `QUANT_SMTP_HOST` - SMTP server hostname
- `QUANT_SMTP_PORT` - SMTP server port (default: 587)
- `QUANT_SMTP_USERNAME` - SMTP authentication username
- `QUANT_SMTP_PASSWORD` - SMTP authentication password
- `QUANT_SMTP_FROM` - From email address
- `QUANT_SMTP_FROM_NAME` - From display name

#### Quant Integration
- `QUANT_ENABLED` - Enable Quant integration
- `QUANT_API_ENDPOINT` - Quant API endpoint
- `QUANT_CUSTOMER` - Your Quant customer ID
- `QUANT_PROJECT` - Your Quant project ID
- `QUANT_TOKEN` - Your Quant API token

### File Storage

The application uses persistent Docker volumes for:
- `content/` - Statamic content (collections, taxonomies, globals, etc.)
- `users/` - User files for flat-file authentication
- `storage/` - Laravel storage (cache, sessions, logs)

## Development

### Artisan Commands

Run Laravel/Statamic Artisan commands using Docker Compose:

```bash
# Generate application key
docker-compose exec statamic php artisan key:generate

# Create a new user
docker-compose exec statamic php please make:user

# Clear cache
docker-compose exec statamic php artisan cache:clear

# Clear Stache (content cache)
docker-compose exec statamic php please stache:clear

# Rebuild Stache
docker-compose exec statamic php please stache:refresh

# Enter tinker REPL
docker-compose exec statamic php artisan tinker
```

### Composer

Install new packages:

```bash
docker-compose exec statamic composer require package-name
```

### Logs

View application logs:

```bash
docker-compose logs -f statamic
```

## Content Management

### Collections

Statamic stores content in the `content/collections/` directory. Each collection has:
- A YAML configuration file (e.g., `pages.yaml`)
- A subdirectory containing entries as Markdown/YAML files

### Blueprints

Content structure is defined in `resources/blueprints/`. Blueprints define the fields and their types for each collection.

### Control Panel

Access the Statamic control panel at `/cp` after creating a user. The control panel provides a beautiful interface for:
- Content management
- User management
- Asset management
- Form submissions
- And more

## Deployment

This template is designed to work seamlessly with Quant Cloud's deployment platform. The Docker container includes all necessary configurations for production deployment.

### Key Production Features

1. **Optimized Dockerfile**: Multi-stage build with proper layer caching
2. **Security**: Runs as www-data user, secure permissions
3. **Performance**: OPcache enabled, Composer autoloader optimization
4. **Logging**: Configured for container-based logging
5. **Health Checks**: Built-in health check endpoints

## Directory Structure

```
app-statamic/
├── src/                    # Statamic application files
│   ├── app/               # Application logic
│   ├── config/            # Configuration files
│   ├── content/           # Content storage (collections, taxonomies, etc.)
│   ├── public/            # Web root (DocumentRoot)
│   ├── resources/         # Views, blueprints, fieldsets
│   ├── routes/            # Route definitions
│   ├── storage/           # File storage (persistent volume)
│   └── users/             # User files (flat-file auth)
├── quant/                 # Quant integration files
│   ├── entrypoints/       # Startup scripts
│   ├── php.ini.d/         # PHP configuration
│   ├── entrypoints.sh     # Main entrypoint script
│   └── meta.json          # Template metadata
├── Dockerfile             # Container definition
├── docker-compose.yml     # Service orchestration
└── README.md              # This file
```

## Troubleshooting

### Application Key Missing

If you see "No application encryption key has been specified":

```bash
docker-compose exec statamic php artisan key:generate
```

### Permission Issues

If you encounter file permission issues:

```bash
docker-compose exec statamic chown -R www-data:www-data /var/www/html/storage /var/www/html/content /var/www/html/users
docker-compose exec statamic chmod -R 775 /var/www/html/storage /var/www/html/content /var/www/html/users
```

### Stache Issues

If content isn't appearing, try clearing and rebuilding the Stache:

```bash
docker-compose exec statamic php please stache:clear
docker-compose exec statamic php please stache:refresh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Docker Compose
5. Submit a pull request

## License

This Statamic application template is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).

Statamic itself requires a license for commercial use. Visit [statamic.com](https://statamic.com) for licensing information.

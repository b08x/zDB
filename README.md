# File Organizer with pgvector

A Ruby application to centralize, organize, and create a searchable knowledge base from your files using PostgreSQL with pgvector for semantic search.

## Features

- File deduplication using SHA256 hashes
- Content extraction from Ruby, Markdown, and PDF files
- Semantic search using pgvector embeddings
- Tagging and categorization system
- Code annotation support for Ruby files
- Duplicate detection and management

## Prerequisites

- Ruby 3.0+
- PostgreSQL 15+ with pgvector extension
- Bundler

### Installing pgvector

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-15-pgvector

# macOS with Homebrew
brew install pgvector

# From source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
make install # may need sudo
```

## Setup

1. Clone the repository and install dependencies:

```bash
bundle install
```

2. Create your PostgreSQL database:

```bash
createdb file_organizer
```

3. Copy and configure the environment file:

```bash
cp .env.example .env
# Edit .env with your database credentials
```

4. Initialize the database:

```bash
./file_organizer_cli.rb setup
```

## Usage

### Scanning directories

Scan a directory and add all files to the database:

```bash
# Add files from a directory
./file_organizer_cli.rb scan ~/Documents

# Dry run to see what would be added
./file_organizer_cli.rb scan ~/Documents --dry-run
```

### Finding duplicates

```bash
./file_organizer_cli.rb find_duplicates
```

### Processing individual files

```bash
./file_organizer_cli.rb process ~/Documents/example.rb
```

### View statistics

```bash
./file_organizer_cli.rb stats
```

## Database Schema

### Files Table
- Tracks all files with their paths, hashes, and metadata
- Detects duplicates via SHA256 hash

### File Contents Table
- Stores extracted text content
- Contains vector embeddings for semantic search
- Supports different content types (raw, extracted, processed)

### Code Annotations Table
- Stores parsed information about code structure
- Tracks classes, methods, functions, etc.

### Tags System
- Flexible tagging for categorization
- Many-to-many relationship with files

## Next Steps

1. **Add embedding generation**: 
   - Integrate OpenAI API or Ollama for generating embeddings
   - Update the `process_*` methods to generate vectors

2. **Implement file moving logic**:
   - Add methods to safely move files to centralized locations
   - Update `centralized_path` in the database

3. **Add more file processors**:
   - Python code parsing
   - Text file processing
   - Image metadata extraction
   - Video/audio transcription

4. **Build search interface**:
   - Semantic search using embeddings
   - Full-text search with BM25
   - Combined ranking algorithms

5. **Create web interface**:
   - Browse organized files
   - Search functionality
   - Tagging interface
   - Duplicate management

## Architecture Decisions

- **Sequel ORM**: Provides a clean Ruby DSL for database operations
- **pgvector**: Enables efficient vector similarity search
- **SHA256 hashing**: Reliable duplicate detection
- **JSONB columns**: Flexible metadata storage
- **Modular processors**: Easy to add support for new file types
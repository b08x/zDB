# frozen_string_literal: true

require 'informers'

module FileOrganizer
  module Embeddings
    class InformersEmbedder
      # Model options with their embedding dimensions
      MODELS = {
        'all-MiniLM-L6-v2' => {
          name: 'sentence-transformers/all-MiniLM-L6-v2',
          dimension: 384,
          description: 'Fast, general-purpose model'
        },
        'all-mpnet-base-v2' => {
          name: 'sentence-transformers/all-mpnet-base-v2',
          dimension: 768,
          description: 'Higher quality, slower'
        },
        'multi-qa-MiniLM-L6-cos-v1' => {
          name: 'sentence-transformers/multi-qa-MiniLM-L6-cos-v1',
          dimension: 384,
          description: 'Optimized for Q&A and semantic search'
        },
        'e5-base-v2' => {
          name: 'intfloat/e5-base-v2',
          dimension: 768,
          description: 'Requires "passage: " and "query: " prefixes'
        },
        'bge-base-en-v1.5' => {
          name: 'BAAI/bge-base-en-v1.5',
          dimension: 768,
          description: 'High-quality embeddings'
        },
        'gte-small' => {
          name: 'Supabase/gte-small',
          dimension: 384,
          description: 'Smaller, faster model'
        }
      }.freeze

      DEFAULT_MODEL = 'all-MiniLM-L6-v2'

      attr_reader :model, :model_name, :dimension

      def initialize(model_name = DEFAULT_MODEL)
        @model_name = model_name
        model_info = MODELS[model_name] || MODELS[DEFAULT_MODEL]
        
        @dimension = model_info[:dimension]
        @model = Informers.pipeline("embedding", model_info[:name])
      end

      def embed(text)
        return nil if text.nil? || text.strip.empty?
        
        # Handle array of texts
        texts = Array(text)
        
        # Add prefixes if needed for certain models
        texts = add_model_prefixes(texts)
        
        # Generate embeddings
        embeddings = @model.(texts)
        
        # Return single embedding or array
        text.is_a?(Array) ? embeddings : embeddings.first
      end

      def embed_batch(texts, batch_size: 32)
        return [] if texts.empty?
        
        all_embeddings = []
        
        texts.each_slice(batch_size) do |batch|
          batch_embeddings = embed(batch)
          all_embeddings.concat(batch_embeddings)
        end
        
        all_embeddings
      end

      def similarity(embedding1, embedding2)
        return 0.0 if embedding1.nil? || embedding2.nil?
        
        # Cosine similarity
        dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
        norm1 = Math.sqrt(embedding1.sum { |x| x ** 2 })
        norm2 = Math.sqrt(embedding2.sum { |x| x ** 2 })
        
        return 0.0 if norm1 == 0 || norm2 == 0
        
        dot_product / (norm1 * norm2)
      end

      private

      def add_model_prefixes(texts)
        case @model_name
        when 'e5-base-v2'
          # E5 models require prefixes
          texts.map { |t| t.start_with?('query:') || t.start_with?('passage:') ? t : "passage: #{t}" }
        when 'bge-base-en-v1.5'
          # BGE models optionally use prefixes for queries
          texts
        else
          texts
        end
      end

      class << self
        def available_models
          MODELS.map do |key, info|
            "#{key} (#{info[:dimension]}d) - #{info[:description]}"
          end
        end

        def model_dimension(model_name)
          MODELS.dig(model_name, :dimension) || MODELS[DEFAULT_MODEL][:dimension]
        end
      end
    end

    # Module for generating embeddings for different content types
    module ContentEmbedder
      class << self
        def embed_file_content(file_content, embedder)
          content = prepare_content(file_content)
          return nil if content.nil? || content.empty?
          
          # Generate embedding
          embedding = embedder.embed(content)
          
          # Update the file_content record
          if embedding && file_content.respond_to?(:embedding=)
            file_content.embedding = Sequel.pg_array(embedding)
            file_content.save
          end
          
          embedding
        end

        def embed_code_file(file_content, embedder)
          # For code files, we might want to include structure info
          content = prepare_code_content(file_content)
          embedder.embed(content)
        end

        def embed_markdown_file(file_content, embedder, metadata = {})
          # Combine content with metadata for richer embeddings
          content = prepare_markdown_content(file_content, metadata)
          embedder.embed(content)
        end

        private

        def prepare_content(file_content)
          return nil unless file_content
          
          text = file_content.content || ""
          
          # Truncate if too long (most models have token limits)
          max_chars = 8000
          text = text[0...max_chars] + "..." if text.length > max_chars
          
          text.strip
        end

        def prepare_code_content(file_content)
          content = file_content.content || ""
          annotations = file_content.annotations || {}
          
          # Include key structural elements
          parts = [content[0...4000]]
          
          if annotations['classes']
            parts << "Classes: #{annotations['classes'].join(', ')}"
          end
          
          if annotations['methods']
            parts << "Methods: #{annotations['methods'].join(', ')}"
          end
          
          parts.join("\n\n")
        end

        def prepare_markdown_content(file_content, metadata)
          parts = []
          
          # Add title if present
          if metadata['title']
            parts << "Title: #{metadata['title']}"
          end
          
          # Add tags/categories
          if metadata['tags']
            parts << "Tags: #{Array(metadata['tags']).join(', ')}"
          end
          
          if metadata['category']
            parts << "Category: #{metadata['category']}"
          end
          
          # Add content
          parts << (file_content.content || "")
          
          parts.join("\n\n")
        end
      end
    end
  end
end
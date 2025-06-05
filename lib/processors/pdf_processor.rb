# frozen_string_literal: true

require 'pycall'
require 'net/http'
require 'json'
require 'base64'
require 'tmpdir'
require 'fileutils'

module FileOrganizer
  module Processors
    class DoclingProcessor
      DEFAULT_SERVICE_URL = 'http://localhost:8000'
      
      attr_reader :service_url

      def initialize(service_url: DEFAULT_SERVICE_URL)
        @service_url = service_url
        
        # Initialize Python environment if needed
        # This could be used for direct docling integration
        begin
          @py_docling = PyCall.import('docling') rescue nil
        rescue PyCall::PyError
          @py_docling = nil
        end
      end

      # Process PDF using docling service
      def process_pdf(file_path)
        return unless File.exist?(file_path)
        
        if @py_docling
          process_with_python(file_path)
        else
          process_with_service(file_path)
        end
      end

      # Process using the docling HTTP service
      def process_with_service(file_path)
        # Submit file for processing
        result = submit_file(file_path)
        return nil unless result[:task_id]

        # Poll for completion
        status = wait_for_completion(result[:status_endpoint])
        return nil unless status[:status] == 'SUCCESS'

        # Extract results
        output_path = retrieve_results(status[:data]['sidekiq_jid'])
        return nil unless output_path

        # Parse extracted content
        parse_docling_output(output_path)
      ensure
        # Cleanup temporary files
        FileUtils.rm_rf(output_path) if output_path && Dir.exist?(output_path)
      end

      # Process directly with Python docling if available
      def process_with_python(file_path)
        return nil unless @py_docling
        
        begin
          # Create docling converter
          converter = @py_docling.DocumentConverter.new
          
          # Convert document
          result = converter.convert(file_path)
          
          # Extract text and metadata
          {
            text: result.document.export_to_markdown,
            metadata: {
              pages: result.document.pages.length,
              tables: result.document.tables.length,
              images: result.document.figures.length
            }
          }
        rescue PyCall::PyError => e
          puts "Python docling error: #{e.message}"
          nil
        end
      end

      private

      def submit_file(file_path)
        uri = URI.join(@service_url, '/convert/file')
        
        request = Net::HTTP::Post.new(uri)
        form_data = [['file', File.open(file_path)]]
        request.set_form(form_data, 'multipart/form-data')
        
        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end
        
        if response.code == '200'
          data = JSON.parse(response.body)
          {
            task_id: data['task_id'],
            status_endpoint: "/tasks/#{data['task_id']}"
          }
        else
          nil
        end
      rescue => e
        puts "Error submitting file: #{e.message}"
        nil
      end

      def wait_for_completion(status_endpoint, max_attempts: 30, delay: 2)
        uri = URI.join(@service_url, status_endpoint)
        
        max_attempts.times do |attempt|
          response = Net::HTTP.get_response(uri)
          
          if response.code == '200'
            data = JSON.parse(response.body)
            
            case data['status']
            when 'SUCCESS'
              return { status: 'SUCCESS', data: data }
            when 'FAILURE'
              return { status: 'FAILURE', error: data['error'] }
            end
          end
          
          sleep(delay)
        end
        
        { status: 'TIMEOUT' }
      rescue => e
        puts "Error checking status: #{e.message}"
        { status: 'ERROR', error: e.message }
      end

      def retrieve_results(job_id)
        # This would retrieve results from Redis or another storage
        # Implementation depends on your docling service setup
        
        # For now, return a mock path
        # In reality, you'd download and extract the ZIP file
        nil
      end

      def parse_docling_output(output_path)
        return nil unless Dir.exist?(output_path)
        
        result = {
          text: '',
          markdown: '',
          metadata: {},
          images: [],
          tables: []
        }
        
        # Look for markdown files
        markdown_files = Dir.glob(File.join(output_path, '*.md'))
        if markdown_files.any?
          result[:markdown] = File.read(markdown_files.first)
          result[:text] = result[:markdown]
        end
        
        # Look for images
        image_files = Dir.glob(File.join(output_path, '*.{png,jpg,jpeg}'))
        result[:images] = image_files.map { |f| File.basename(f) }
        
        # Look for metadata
        if File.exist?(File.join(output_path, 'metadata.json'))
          result[:metadata] = JSON.parse(File.read(File.join(output_path, 'metadata.json')))
        end
        
        result
      end
    end

    # Alternative pure Ruby PDF processor using pdf-reader
    class SimplePdfProcessor
      def self.process(file_path)
        require 'pdf-reader'
        
        reader = PDF::Reader.new(file_path)
        
        {
          text: reader.pages.map(&:text).join("\n"),
          metadata: {
            page_count: reader.page_count,
            info: reader.info,
            metadata: reader.metadata
          }
        }
      rescue => e
        puts "Error processing PDF: #{e.message}"
        nil
      end
    end
  end
end
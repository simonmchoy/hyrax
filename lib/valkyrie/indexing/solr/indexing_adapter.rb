# frozen_string_literal: true
require 'rsolr'

module Valkyrie
  module Indexing
    module Solr
      class IndexingAdapter
        COMMIT_PARAMS = { softCommit: true }.freeze
        ##
        # @!attribute [r] connection
        #   @return [RSolr::Client]
        # @!attribute [r] resource_indexer
        #   @return [Class]
        attr_reader :connection, :resource_indexer

        ##
        # @param connection [RSolr::Client] The RSolr connection to index to.
        # @param resource_indexer [Class, #to_solr] An indexer which is able to
        #   receive a `resource` argument and then has an instance method `#to_solr`
        def initialize(connection: default_connection, resource_indexer: default_indexer)
          @connection = connection
          @resource_indexer = resource_indexer
        end

        def save(resource:)
          persist([resource])
        end

        private

          def persist(resources)
            documents = resources.map do |resource|
              solr_document(resource)
            end
            add_documents(documents)
          end

          def solr_document(resource)
            base_hash(resource).merge(resource_indexer.new(resource: resource).to_solr)
          end

          def add_documents(documents)
            connection.add documents, params: COMMIT_PARAMS
          end

          def base_hash(resource)
            {
              "id": resource.id.to_s,
              "created_at_dtsi": resource.created_at,
              "updated_at_dtsi": resource.updated_at
            }
          end

          ##
          # Index configuration based on the blacklight connection.
          def blacklight_based_config
            begin
              # If Blacklight raises an error, we're hopefully running a
              # generator now (if not, the application has bigger problems
              # than this missing configuration)
              bl_index = Blacklight.default_index.connection.uri
            rescue RuntimeError
              return {}
            end

            { 'host' => bl_index.host,
              'port' => bl_index.port,
              'core' => 'hyrax-valkyrie' }
          end

          def connection_url
            config = begin
                       Rails.application.config_for(:valkyrie_index).compact
                     rescue RuntimeError
                       {}
                     end

            # if any configuration is missing, derive it from Blacklight
            config = blacklight_based_config.merge(config)

            "http://#{config['host']}:#{config['port']}/solr/#{config['core']}"
          end

          def default_connection
            RSolr.connect(url: connection_url)
          end

          def default_indexer
            Valkyrie::Persistence::Solr::MetadataAdapter::NullIndexer
          end
      end
    end
  end
end

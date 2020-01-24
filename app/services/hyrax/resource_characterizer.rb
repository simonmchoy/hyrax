# frozen_string_literal: true

module Hyrax
  ##
  # Propogates visibility from a given Work to its FileSets
  class ResourceCharacterizer
    ##
    # @!attribute [rw] source
    #   @return [#visibility]
    attr_accessor :source

    ##
    # @param source [#visibility] the object to propogate visibility from
    def initialize(source:)
      self.source = source
    end

    ##
    # @return [void]
    #
    # @raise [RuntimeError] if visibility propogation fails
    def characterize
      Hydra::Works::CharacterizationService.run(characterization_proxy, filepath)
      Rails.logger.debug "Ran characterization on #{characterization_proxy.id} (#{characterization_proxy.mime_type})"
      characterization_proxy.alpha_channels = channels(filepath) if source.image? && Hyrax.config.iiif_image_server?
      persist
      CreateDerivativesJob.perform_later(source, source.original_file.id, filepath)
    end

    private

      def persist
        Hyrax.persister.save(resource: characterization_proxy)
        Hyrax.persister.save(resource: source)
      end

      def characterization_proxy
        raise "#{source.class.characterization_proxy} was not found for FileSet #{source.id}" unless source.characterization_proxy?
        source.characterization_proxy
      end

      def filepath
        Hyrax::WorkingDirectory.find_or_retrieve(source.original_file.id, source.id.id)
      end

      def channels(path)
        ch = MiniMagick::Tool::Identify.new do |cmd|
          cmd.format '%[channels]'
          cmd << path
        end
        [ch]
      end
  end
end

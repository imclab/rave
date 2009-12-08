#Represents a Blip, owned by a Wavelet
module Rave
  module Models
    class Blip < Component
      include Rave::Mixins::TimeUtils
      
      JAVA_CLASS = 'com.google.wave.api.impl.BlipData' # :nodoc:
      
      attr_reader :annotations, :child_blip_ids, :contributor_ids,
                  :elements, :last_modified_time, :parent_blip_id, :version, :wave_id,
                  :wavelet_id

      VALID_STATES = [:normal, :null, :deleted] # As passed to initializer in :state option.
      VALID_CREATIONS = [:original, :generated, :virtual] # As passed to initializer in :creation option.
      
      @@next_id = 1 # Unique ID for newly created blips.
      
      #Options include:
      # - :annotations
      # - :child_blip_ids
      # - :content
      # - :contributors
      # - :creator
      # - :elements
      # - :last_modified_time
      # - :parent_blip_id
      # - :version
      # - :wave_id
      # - :wavelet_id
      # - :id
      # - :context
      # - :state
      # - :creation
      def initialize(options = {})
        @annotations = options[:annotations] || []
        @child_blip_ids = options[:child_blip_ids] || []
        @content = options[:content] || ''
        @contributor_ids = options[:contributors] || []
        @creator = options[:creator]
        @elements = options[:elements] || {}
        @last_modified_time = time_from_json(options[:last_modified_time]) || Time.now
        @parent_blip_id = options[:parent_blip_id]
        @version = options[:version] || -1
        @wave_id = options[:wave_id]
        @wavelet_id = options[:wavelet_id]
        @state = options[:state] || :normal
        @creation = options[:creation] || :original

        unless VALID_STATES.include? @state
          raise ArgumentError.new("Bad state #{options[:state]}. Should be one of #{VALID_STATES.join(', ')}")
        end

        unless VALID_CREATIONS.include? @creation
          raise ArgumentError.new("Bad creation #{options[:creation]}. Should be one of #{VALID_CREATIONS.join(', ')}")
        end

        # If the blip doesn't have a defined ID, since we just created it,
        # assign a temporary, though unique, ID, based on the ID of the wavelet.
        if options[:id].nil?
          options[:id] = "#{GENERATED_PREFIX}_#{@wavelet_id}_#{@@next_id}"
          @@next_id += 1
        end

        super(options)
      end
      
      #Returns true if this is a root blip (no parent blip)
      def root?; @parent_blip_id.nil?; end

      # Returns true if this is a leaf node (has no children).
      def leaf?; @child_blip_ids.empty?; end

      # Has the blip been deleted?
      def deleted?; [:deleted, :null].include? @state; end

      # Has the blip been completely destroyed?
      def null?; @state == :null; end

      # Has the blip been generated by the operations of the robot?
      def generated?; @creation == :generated; end

      # Has the blip been inferred from reference?
      def virtual?; @creation == :virtual; end

      # Has the blip been passed from wave, rather than being inferred or created locally?
      def original?; @creation == :original; end

      # Text contained in the blip.
      def content; @content.dup; end
      
      #Returns true if an annotation with the given name exists in this blip
      def has_annotation?(name)
        @annotations.any? { |a| a.name == name }
      end

      # Users that have made a contribution to the blip.
      def contributors
        @contributor_ids.map { |c| @context.users[c] }
      end

      # Original creator of the blip.
      def creator
        @context.users[@creator]
      end
      
      #Creates a child blip under this blip
      def create_child_blip
        blip = Blip.new(:wave_id => @wave_id, :parent_blip_id => @id, :wavelet_id => @wavelet_id,
          :context => @context, :contributors => [Robot.instance.id], :creation => :generated)
        @context.operations << Operation.new(:type => Operation::BLIP_CREATE_CHILD, :blip_id => @id, :wave_id => @wave_id, :wavelet_id => @wavelet_id, :property => blip)
        add_child_blip(blip)
        blip
      end

      # Adds a created child blip to this blip.
      def add_child_blip(blip) # :nodoc:
        @child_blip_ids << blip.id
        @context.add_blip(blip)
      end

      # INTERNAL
      # Removed a child blip.
      def remove_child_blip(blip) # :nodoc:
        @child_blip_ids.delete(blip.id)

        # Destroy oneself completely if you are no longer useful to structure.
        destroy_me if deleted? and leaf? and not root?
      end

      # List of direct children of this blip. The first one will be continuing
      # the thread, others will be indented replies.
      def child_blips
        @child_blip_ids.map { |id| @context.blips[id] }
      end
      
      # Delete this blip from its wavelet.
      # Returns the blip id.
      def delete
        if deleted?
          LOGGER.warning("Attempt to delete blip that has already been deleted: #{id}")
        elsif root?
          LOGGER.warning("Attempt to delete root blip: #{id}")
        else
          @context.operations << Operation.new(:type => Operation::BLIP_DELETE,
            :blip_id => @id, :wave_id => @wave_id, :wavelet_id => @wavelet_id)
          delete_me
        end
      end
      
      # Wavelet that the blip is a part of.
      def wavelet
        @context.wavelets[@wavelet_id]
      end

      def wave
        @context.waves[@wave_id]
      end

      # Blip that this Blip is a direct reply to. Will be nil if the root blip
      # in a wavelet.
      def parent_blip
        @context.blips[@parent_blip_id]
      end

      # Convert to string.
      def to_s
        str = @content.gsub(/\n/, "\\n")
        str = str.length > 24 ? "#{str[0..20]}..." : str
        
        str = case @state
        when :normal
          "#{contributors.join(',')}:#{str}"
        when :deleted
          '<DELETED>'
        when :null
          '<NULL>'
        end

        "#{super}:#{str}"
      end

      # *INTERNAL*
      # Write out a formatted block of text showing the blip and its descendants.
      def print_structure(indent = 0) # :nodoc:
        str = "#{'  ' * indent}#{to_s}\n"
        
        children = child_blips

        # All children, except the first, should be indented.
        children.each_with_index do |blip, index|
          # Gap between reply chains.
          if index > 1
            str << "\n"
          end

          if index > 0
            str << blip.print_structure(indent + 1)
          end
        end

        if children[0]
          str << children[0].print_structure(indent)
        end

        str
      end

      # Convert to json for sending in an operation. We should never need to
      # send more data than this, although blips we receive will have more data.
      def to_json
        {
          'blipId' => @id,
          'javaClass' => JAVA_CLASS,
          'waveId' => @wave_id,
          'waveletId' => @wavelet_id
        }.to_json
      end

    protected
      # *INTERNAL*
      # Delete the blip or, if appropriate, destroy it instead.
      def delete_me # :nodoc:
        raise "Can't delete root blip" if root?

        if leaf?
          destroy_me
        else
          # Blip is marked as deleted, but stays in place to maintain structure.
          @state = :deleted
          @content = ''
        end

        @id
      end

      # *INTERNAL*
      # Remove the blip entirely, leaving it null.
      def destroy_me # :nodoc:
        raise "Can't destroy root blip" if root?
        raise "Can't destroy non-leaf blip" unless leaf?

        # Remove the blip entirely to the realm of oblivion.
        parent_blip.remove_child_blip(self)
        @parent_blip_id = nil
        @context.remove_blip(self)
        @state = :null
        @content = ''

        @id
      end
    end
  end
end

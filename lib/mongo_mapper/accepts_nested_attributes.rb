# This is an incomplete implementation.
module MongoMapper
  module NestedAttributes
    extend ActiveSupport::Concern

    module ClassMethods
      def accepts_nested_attributes_for(*attr_names)
        begin
          options = { :allow_destroy => false }
          options.update(attr_names.extract_options!)
          options.assert_valid_keys(:allow_destroy, :reject_if)


          (attr_names||[]).each do |association|
            # should do a fake nested attributes
            define_method :"#{association}_attributes=" do |*args|
              self.send :"#{association}=", *args
            end
          end
        rescue
          return
        end
      end
    end

    UNASSIGNABLE_KEYS = %w{ id _id _destroy }

    def assign_nested_attributes_for_association(association_name, attributes_collection, allow_destroy)
      unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
        raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
      end

      if attributes_collection.is_a? Hash
        attributes_collection = attributes_collection.sort_by { |index, _| index.to_i }.map { |_, attributes| attributes }
      end


      attributes_collection.each do |attributes|
        attributes.stringify_keys!

        if attributes['_id'].blank?
          send(association_name) << association_name.to_s.classify.constantize.new(attributes)
        elsif existing_record = send(association_name).detect { |record| record.id.to_s == attributes['_id'].to_s }
          if existing_record.has_destroy_flag?(attributes) && allow_destroy
            send(association_name).delete(existing_record)
            existing_record.destroy unless association_name.to_s.classify.constantize.embeddable?
          else
            existing_record.attributes = attributes.except(*UNASSIGNABLE_KEYS)
          end
        end
      end

    end


    def has_destroy_flag?(hash)
      Boolean.to_mongo(hash['_destroy'])
    end

  end
end

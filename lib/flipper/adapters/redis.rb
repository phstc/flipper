require 'set'
require 'redis'
require 'flipper'

module Flipper
  module Adapters
    class Redis
      include ::Flipper::Adapter

      # Private: The key that stores the set of known features.
      FeaturesKey = :flipper_features

      # Public: The name of the adapter.
      attr_reader :name

      # Public: Initializes a Redis flipper adapter.
      #
      # client - The Redis client to use. Feel free to namespace it.
      def initialize(client)
        @client = client
        @name = :redis
      end

      def features
        read_feature_keys
      end

      def add(feature)
        @client.sadd FeaturesKey, feature.key
        true
      end

      def remove(feature)
        @client.multi do
          @client.srem FeaturesKey, feature.key
          @client.del feature.key
        end
        true
      end

      def clear(feature)
        @client.del feature.key
        true
      end

      def get(feature)
        doc = doc_for(feature)
        result_for_feature(feature, doc)
      end

      def get_multi(features)
        read_many_features(features)
      end

      def get_all
        features = read_feature_keys.map { |key| Flipper::Feature.new(key, self) }
        read_many_features(features)
      end

      def enable(feature, gate, thing)
        case gate.data_type
        when :boolean, :integer
          @client.hset feature.key, gate.key, thing.value.to_s
        when :set
          @client.hset feature.key, to_field(gate, thing), 1
        else
          unsupported_data_type gate.data_type
        end

        true
      end

      def disable(feature, gate, thing)
        case gate.data_type
        when :boolean
          @client.del feature.key
        when :integer
          @client.hset feature.key, gate.key, thing.value.to_s
        when :set
          @client.hdel feature.key, to_field(gate, thing)
        else
          unsupported_data_type gate.data_type
        end

        true
      end

      private

      def read_many_features(features)
        docs = docs_for(features)
        result = {}
        features.zip(docs) do |feature, doc|
          result[feature.key] = result_for_feature(feature, doc)
        end
        result
      end

      def read_feature_keys
        @client.smembers(FeaturesKey).to_set
      end

      # Private: Gets a hash of fields => values for the given feature.
      #
      # Returns a Hash of fields => values.
      def doc_for(feature)
        @client.hgetall(feature.key)
      end

      def docs_for(features)
        @client.pipelined do
          features.each do |feature|
            doc_for(feature)
          end
        end
      end

      def result_for_feature(feature, doc)
        result = {}
        fields = doc.keys

        feature.gates.each do |gate|
          result[gate.key] =
            case gate.data_type
            when :boolean, :integer
              doc[gate.key.to_s]
            when :set
              fields_to_gate_value fields, gate
            else
              unsupported_data_type gate.data_type
            end
        end

        result
      end

      # Private: Converts gate and thing to hash key.
      def to_field(gate, thing)
        "#{gate.key}/#{thing.value}"
      end

      # Private: Returns a set of values given an array of fields and a gate.
      #
      # Returns a Set of the values enabled for the gate.
      def fields_to_gate_value(fields, gate)
        regex = %r{^#{Regexp.escape(gate.key.to_s)}/}
        keys = fields.grep(regex)
        values = keys.map { |key| key.split('/', 2).last }
        values.to_set
      end

      # Private
      def unsupported_data_type(data_type)
        raise "#{data_type} is not supported by this adapter"
      end
    end
  end
end

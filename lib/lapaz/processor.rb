module Lapaz
  module Processor

    class YamlProcessor < Lapaz::Component
      def producer?; false; end
      def consumer?; false; end
      def work(msg)
        print "^#{sequence_id}|"
        key,obj = :warnings,"YamlProcessor: no work to do"
        if msg.headers[:file_contents_type] == 'yaml'
          xfrm = YAML.parse(msg.body[:file_contents]).transform
          key,obj = :body,{xfrm.type_id.to_sym => [xfrm.value]}
          print '.'
          msg.headers.delete(:file_contents_type)
          msg.body.delete(:file_contents)
        else
          print ','
        end
        msg.add_to key,obj
      end
    end

  end
end

module Korwe
  module TheCore
    class TypeDefinition
      attr_accessor :name,  :type_properties, :inherits_from

      def initialize(name)
        self.name=name
        self.type_properties=Hash.new
      end
    end

    class PrimitiveTypeDefinition < TypeDefinition
      attr_accessor :klass

      def initialize(name, klass)
        super(name)
        self.klass= klass
      end
    end

    class GenericTypeDefinition < TypeDefinition
      attr_accessor :type_parameters

      def initialize(name)
        super(name)
        self.type_parameters= Array.new
      end
    end

    class ExternalTypeDefinition < PrimitiveTypeDefinition
      def initialize(name, klass)
        super(name, klass)
      end
    end

    class ServiceDefinition
      attr_accessor :name, :method_list

      def initialize(name)
        self.name=name
        self.method_list=Hash.new
      end
    end

    class ServiceMethod
      attr_accessor :name, :description, :parameters, :return_type

      def initialize(name)
        self.name=name
        self.parameters= Hash.new
      end
    end

    class ApiDefinition
      PRIMITIVE_TYPES = {'Integer' => PrimitiveTypeDefinition.new('int', Integer), 'String'=> PrimitiveTypeDefinition.new('string', String),
                         'Long'=>PrimitiveTypeDefinition.new('long', Integer), 'Float'=>PrimitiveTypeDefinition.new('float', Float), 'Boolean'=>TypeDefinition.new('boolean'),
                         'Double'=>PrimitiveTypeDefinition.new('double', Float), 'Date'=>PrimitiveTypeDefinition.new('date', DateTime)}

      GENERIC_TYPES = {'Map'=>GenericTypeDefinition.new('map'), 'List'=>GenericTypeDefinition.new('list'), 'Set'=>GenericTypeDefinition.new('set')}

      attr_accessor :types, :services
      def initialize(api_directory)
        self.types= Hash.new
        self.services= Hash.new

        initialize_types api_directory + File::SEPARATOR + "types"
        self.types.merge! PRIMITIVE_TYPES
        self.types.merge! GENERIC_TYPES
        initialize_services api_directory + File::SEPARATOR + "services"
        #Do this last so that we don't need to manage dependency loading - performance hit, but 1 time only
        initialize_inheritance
      end

      def initialize_types(types_path)
        Dir.glob( types_path + File::SEPARATOR + "**" + File::SEPARATOR + "*.yaml" ).each do |type_path|
          initialize_type(type_path)
        end
      end

      def initialize_type(type_file)
        yaml = YAML::load_file(type_file)
        constant_name = yaml['name'].split('.').collect{|ns| ns.slice(0,1).capitalize + ns.slice(1..-1)}.join("::")
        const = nil
        begin
          const = eval("::#{constant_name}")
        rescue NameError
          puts "Warning: No class exists for #{constant_name}"
        end
        type = ExternalTypeDefinition.new(yaml['name'], const)
        yaml['attributes'].each do |attribute_definition|
          type_parameter_offset = attribute_definition['type'].index('<')
          #TODO: Do something with generic type parameters
          type.type_properties[attribute_definition['name']] = type_parameter_offset.nil? ? attribute_definition['type'].strip : attribute_definition['type'].slice(0,type_parameter_offset).strip
        end if yaml['attributes']

        type.inherits_from=yaml['inherits_from']
        self.types[type.name] = type
      end


      def initialize_services(services_path)
        Dir.glob(services_path + File::SEPARATOR + "**" + File::SEPARATOR + "*.yaml").each do |service_path|
          initialize_service(service_path)
        end
      end

      def initialize_service(service_file)
        yaml = YAML::load_file(service_file)
        service = ServiceDefinition.new(yaml['name'])

        #process function definitions
        yaml['functions'].each do |function_definition|
          method = ServiceMethod.new(function_definition['name'])
          method.description= function_definition['description']
          method.return_type= function_definition['return_type']

          #process function's parameters
          function_definition['parameters'].each do |param_def|
            method.parameters[param_def['name']] = param_def['type']
          end if function_definition['parameters']

          service.method_list[method.name] = method
        end

        self.services[service.name] = service
      end


      def initialize_inheritance
        processed = []
        #loop through all type defitions merging properties of the parent class

        process_inheritance = Proc.new do |type_def, proc|
          unless processed.any?{|name| type_def.inherits_from==name}
            unless type_def.inherits_from.nil?
              #Depth first
              parent_type = types[type_def.inherits_from]
              proc.call(parent_type)
              #now merge
              type_def.type_properties.merge! parent_type.type_properties
            end
          end
        end

        self.types.values.each do |type_definition|
          process_inheritance.call(type_definition, process_inheritance)
        end
      end
    end
  end
end

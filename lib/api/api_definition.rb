module Korwe
  module TheCore
    class TypeDefinitionAttribute
      attr_accessor :name, :type, :type_parameters
    end

    class TypeDefinition
      attr_accessor :name,  :type_attributes, :inherits_from, :inherited

      def inherited?
        self.inherited
      end

      def initialize(name)
        self.name=name
        self.type_attributes=Hash.new
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
      PRIMITIVE_TYPES = {'Object'=>PrimitiveTypeDefinition.new('object',nil), 'Integer' => PrimitiveTypeDefinition.new('int', Integer), 'String'=> PrimitiveTypeDefinition.new('string', String),
                         'Long'=>PrimitiveTypeDefinition.new('long', Integer), 'Float'=>PrimitiveTypeDefinition.new('float', Float), 'Boolean'=>TypeDefinition.new('boolean'),
                         'TrueClass'=>TypeDefinition.new('boolean'), 'FalseClass'=>TypeDefinition.new('boolean'),
                         'Double'=>PrimitiveTypeDefinition.new('double', Float), 'DateTime'=>PrimitiveTypeDefinition.new('DateTime', Time)}
      PRIMITIVE_TYPES['Object'].inherited=true
      BASIC_GENERIC_TYPES = {'Map'=>GenericTypeDefinition.new('map'), 'List'=>GenericTypeDefinition.new('list'), 'Set'=>GenericTypeDefinition.new('set')}

      attr_accessor :types, :services
      def initialize(api_directory)
        self.types= Hash.new
        self.services= Hash.new

        initialize_types api_directory + File::SEPARATOR + "types"
        self.types.merge! PRIMITIVE_TYPES
        self.types.merge! BASIC_GENERIC_TYPES
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

        type = self.types[yaml['name']] || ExternalTypeDefinition.new(yaml['name'], api_type_constant(yaml['name']))
        yaml['attributes'].each do |attribute_definition|
          attribute = attr_def_to_type_def_attr(attribute_definition['name'], attribute_definition['type'])
          type.type_attributes[attribute.name] = attribute
        end if yaml['attributes']

        type.inherits_from=yaml['inherits_from']
        if type.inherits_from
          inherited_type = self.types[type.inherits_from]
          if inherited_type.nil?
            inherited_type = self.types[type.inherits_from] || ExternalTypeDefinition.new(type.inherits_from, api_type_constant(type.inherits_from))
            self.types[inherited_type.name] = inherited_type
          end

          inherited_type.inherited=true
        end

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

          unless(function_definition['return_type'].nil?)
            method.return_type= function_definition['return_type']
            define_type_reference(method.return_type)
          end

          #process function's parameters
          function_definition['parameters'].each do |param_def|
            method.parameters[param_def['name']] = param_def['type']
            define_type_reference(param_def['type'])
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
              proc.call(parent_type, proc)
              #now merge
              type_def.type_attributes.merge! parent_type.type_attributes
            end
          end
        end

        self.types.values.each do |type_definition|
          process_inheritance.call(type_definition, process_inheritance)
        end
      end

      def attr_def_to_type_def_attr(attr_name, type_def_name)

        attribute = TypeDefinitionAttribute.new
        attribute.name = attr_name
        type_parameter_offset = type_def_name.index('<')

        if type_parameter_offset.nil?
          attribute.type = type_def_name.strip
        else
          attribute.type = type_def_name.slice(0,type_parameter_offset).strip
          attribute.type_parameters = type_def_name.slice((type_parameter_offset+1)..-2).split(',').collect{|tp| tp.strip}
        end
        attribute
      end

      def api_type_constant(name)
        constant_name = name.split('.').collect{|ns| ns.slice(0,1).capitalize + ns.slice(1..-1)}.join("::")
        const = nil
        begin
          const = eval("::#{constant_name}")
        rescue NameError
          puts "Warning: No class exists for #{constant_name}"
        end
        const
      end

      def define_type_reference(type_def_name)
        if self.types[type_def_name].nil?
          type_parameter_offset = type_def_name.index('<')

          if type_parameter_offset.nil?
            type = GenericTypeDefinition.new(type_def_name.strip)
          else
            class_name = type_def_name.slice(0,type_parameter_offset).strip
            #if basic generic
            if BASIC_GENERIC_TYPES.has_key?(class_name)
              type = GenericTypeDefinition.new(BASIC_GENERIC_TYPES[class_name].name)
            else
              #TODO: Handle custom generics
              raise NotImplementedError
            end
            type.type_parameters = type_def_name.slice((type_parameter_offset+1)..-2).split(',').collect{|tp| tp.strip}
          end
          self.types[type_def_name] = type
        end
      end
    end
  end
end

module ReactOnRails
  class Railtie < Rails::Railtie
    initializer "react_on_rails.scout_apm_instrumentation", after: "scout_apm.start" do |app|
      next unless defined? ScoutApm

      ReactOnRails::Helper.class_eval do
        include ScoutApm::Tracer
        instrument_method :react_component, type: "ReactOnRails", name: "react_component"
        instrument_method :react_component_hash, type: "ReactOnRails", name: "react_component_hash"
      end

      ReactOnRails::ServerRenderingPool::RubyEmbeddedJavaScript.singleton_class.class_eval do
        include ScoutApm::Tracer
        instrument_method :exec_server_render_js, type: "ReactOnRails", name: "ExecJs React Server Rendering"
      end
    end
  end
end

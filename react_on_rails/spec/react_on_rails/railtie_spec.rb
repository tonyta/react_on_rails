# frozen_string_literal: true

require_relative "spec_helper"

module ReactOnRails
  RSpec.describe Railtie do
    it "defines a named Rails initializer to run after scout_apm.start" do
      expect(described_class.initializers).to be_one

      initializer = described_class.initializers.first
      expect(initializer.name).to eq "react_on_rails.scout_apm_instrumentation"
      expect(initializer.after).to eq "scout_apm.start"
    end

    describe "react_on_rails.scout_apm_instrumentation initializer" do
      subject(:initializer) { described_class.initializers.first }

      let(:mock_helper) { Module.new.include(ReactOnRails::Helper) }
      let(:mock_rb_ebedded_js) { Class.new(ReactOnRails::ServerRenderingPool::RubyEmbeddedJavaScript) }

      before do
        stub_const("ReactOnRails::Helper", mock_helper)
        stub_const("ReactOnRails::ServerRenderingPool::RubyEmbeddedJavaScript", mock_rb_ebedded_js)
      end

      context "when ScoutApm is not defined" do
        it "does not instrument Helper#react_component" do
          initializer.run
          expect(mock_helper.instance_methods(false)).not_to include(:react_component_with_test_instrumentation)
          expect(mock_helper.instance_methods(false)).not_to include(:react_component_without_test_instrumentation)
        end

        it "does not instrument Helper#react_component_hash" do
          initializer.run
          expect(mock_helper.instance_methods(false)).not_to include(:react_component_hash_with_test_instrumentation)
          expect(mock_helper.instance_methods(false)).not_to include(:react_component_hash_without_test_instrumentation)
        end

        it "does not instrument RubyEmbeddedJavaScript.exec_server_render_js" do
          initializer.run
          expect(mock_rb_ebedded_js.methods(false)).not_to include(:exec_server_render_js_with_test_instrumentation)
          expect(mock_rb_ebedded_js.methods(false)).not_to include(:exec_server_render_js_without_test_instrumentation)
        end
      end

      context "when ScoutApm is defined" do
        let(:fake_scout_tracer) do
          #
          # Simplified mock of ScoutApm::Tracer that mirrors its real implementation.
          # https://github.com/scoutapp/scout_apm_ruby/blob/v6.1.0/lib/scout_apm/tracer.rb#L47-L70
          #
          Module.new do
            def self.included(base)
              base.extend(ClassMethods)
            end

            module ClassMethods
              def instrument_method(method_name, **)
                raise "method does not exist: #{method_name}" unless method_defined?(method_name)

                instrumented_name = :"#{method_name}_with_test_instrumentation"
                uninstrumented_name = :"#{method_name}_without_test_instrumentation"

                define_method(instrumented_name) do |*args, **kwargs, &block|
                  send(uninstrumented_name, *args, **kwargs, &block)
                end

                alias_method uninstrumented_name, method_name
                alias_method method_name, instrumented_name
              end
            end
          end
        end

        before { stub_const("ScoutApm::Tracer", fake_scout_tracer) }

        it "instruments Helper#react_component" do
          initializer.run
          expect(mock_helper.instance_methods(false)).to include(:react_component_with_test_instrumentation)
          expect(mock_helper.instance_methods(false)).to include(:react_component_without_test_instrumentation)
        end

        it "instruments Helper#react_component_hash" do
          initializer.run
          expect(mock_helper.instance_methods(false)).to include(:react_component_hash_with_test_instrumentation)
          expect(mock_helper.instance_methods(false)).to include(:react_component_hash_without_test_instrumentation)
        end

        it "instruments RubyEmbeddedJavaScript.exec_server_render_js" do
          initializer.run
          expect(mock_rb_ebedded_js.methods(false)).to include(:exec_server_render_js_with_test_instrumentation)
          expect(mock_rb_ebedded_js.methods(false)).to include(:exec_server_render_js_without_test_instrumentation)
        end
      end
    end
  end
end

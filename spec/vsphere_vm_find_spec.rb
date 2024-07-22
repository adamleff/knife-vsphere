require "spec_helper"
require "chef/knife/vsphere_vm_find"
require "ostruct"

class Hash
  # An artifact of me using hashes to represent the VM -- the method needs to be there to mock
  def obj
    raise "You shouldn't be calling me"
  end
end

describe Chef::Knife::VsphereVmFind do
  subject { described_class.new }

  let(:ui) { double("ChefUI") }

  let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn" } }
  let(:vm2) { { "name" => "another", "runtime.powerState" => "poweredOn" } }

  let(:expected_properties) { [ "name", "runtime.powerState" ] }
  let(:returned_vms) { [ vm1 ] }

  before do
    described_class.load_deps
    expect(subject).to receive(:ui).and_return(ui)
    expect(subject).to receive(:get_all_vm_objects).with(properties: expected_properties).and_return(returned_vms)
  end

  context "matching vm names" do
    let(:returned_vms) { [ vm1, vm2 ] }

    it "returns only matching vms" do
      subject.config[:matchname] = "myvm"

      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm" }])

      subject.run
    end
  end

  context "matching ips" do
    let(:returned_vms) { [ vm1, vm2 ] }
    let(:expected_properties) { [ "name", "runtime.powerState", "guest.ipAddress" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "guest.ipAddress" => "1.2.3.4" } }
    let(:vm2) { { "name" => "another", "runtime.powerState" => "poweredOn", "guest.ipAddress" => "4.5.6.7" } }

    it "returns only matching vms" do
      subject.config[:matchip] = "1.2.3"

      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "ip" => "1.2.3.4" }])

      subject.run
    end
  end

  context "matching ips and names" do
    let(:returned_vms) { [ vm1, vm2 ] }
    let(:expected_properties) { [ "name", "runtime.powerState", "guest.ipAddress" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "guest.ipAddress" => "1.2.3.4" } }
    let(:vm2) { { "name" => "another", "runtime.powerState" => "poweredOn", "guest.ipAddress" => "4.5.6.7" } }

    it "returns only the vm that matches both" do
      subject.config[:matchip] = "4"
      subject.config[:matchname] = "myvm"

      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "ip" => "1.2.3.4" }])

      subject.run
    end
  end

  context "asking for a hostname" do
    let(:expected_properties) { [ "name", "runtime.powerState", "guest.hostName" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "guest.hostName" => "thehost.example.com" } }

    before do
      subject.config[:hostname] = true
    end

    it "includes the hostname in the output" do
      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "hostname" => "thehost.example.com" }])

      subject.run
    end
  end

  context "asking for the name of the guests host" do
    let(:expected_properties) { [ "name", "runtime.powerState", "summary.runtime.host" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "summary.runtime.host" => OpenStruct.new(name: "host1") } }

    before do
      subject.config[:host_name] = true
    end
    it "includes the host_name in the output" do
      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "host_name" => "host1" }])

      subject.run
    end
  end

  context "asking for the networks" do
    let(:expected_properties) { [ "name", "runtime.powerState", "guest.net" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "guest.net" => networks } }

    before do
      subject.config[:networks] = true
    end

    context "a single network" do
      let(:net1) { double("Network", network: "VLAN1", ipConfig: ipconfig1) }
      let(:ipconfig1) { double("IPconfig", ipAddress: [ip1] ) }
      let(:ip1) { double("IPAddress", ipAddress: "1.2.3.4", prefixLength: "24") }
      let(:networks) { [ net1 ] }

      before do
      end

      it "returns the network and IP" do
        expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "networks" => [ { "name" => "VLAN1", "ip" => "1.2.3.4", "prefix" => "24" }] }])
        subject.run
      end
    end

    context "multiple networks" do
    end
  end

  context "asking for the full path" do
    let(:parent1) { double("Parent", name: "vms", parent: nil) }
    let(:parent2) { double("Parent", name: "projectX", parent: parent1) }

    before do
      subject.config[:full_path] = true
      allow(vm1).to receive(:obj).and_return(vmobj)
    end

    context "with one path element" do
      let(:vmobj) { double("FullVMObject", parent: parent1) }

      it "returns the name of the folder" do
        expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "folder" => "vms" }])
        subject.run
      end
    end

    context "with a nested folder" do
      let(:vmobj) { double("FullVMObject", parent: parent2) }

      it "returns the name of the folder" do
        expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "folder" => "vms/projectX" }])
        subject.run
      end
    end
  end

  context "asking for the os disks" do
    let(:disk1) { double("Disk", capacity: 10000 * 1024 * 1024, diskPath: "disk1", freeSpace: 500 * 1024 * 1024) }
    let(:expected_properties) { [ "name", "runtime.powerState", "guest.disk" ] }
    let(:vm1) { { "name" => "myvm", "runtime.powerState" => "poweredOn", "guest.disk" => [disk1] } }
    before do
      subject.config[:os_disk] = true
    end

    it "returns the disks" do
      expect(ui).to receive(:output).with([{ "state" => "on", "name" => "myvm", "disks" => [ { "name" => "disk1", "capacity" => 10000, "free" => 500 } ] }])
      subject.run
    end
  end
end

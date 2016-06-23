
all: kilo-testing.yaml liberty-testing.yaml

kilo-testing.yaml: gen-bundle.sh
	./gen-bundle.sh kilo ppa:project-calico/kilo-testing > $@

liberty-testing.yaml: gen-bundle.sh
	./gen-bundle.sh liberty ppa:project-calico/liberty-testing > $@

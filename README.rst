=============================
Calico/OpenStack Juju bundles
=============================

This repository contains Juju bundles - or code for generating Juju bundles -
for deploying a Calico/OpenStack cluster on Ubuntu, with various combinations
of:

- the Ubuntu platform (Trusty or Xenial)

- the OpenStack release (Icehouse, Kilo, Liberty, Mitaka or Newton)

- the Calico code (1.3 or 1.4).

Specifically we have the following subdirectories:

- calico-newton-juju2: Bundle for Newton OpenStack with Calico 1.4 on Xenial
  nodes (except for MySQL on Trusty), for deployment using Juju 2.

- calico-mitaka-juju2: Bundle for Mitaka OpenStack with Calico 1.4 on Xenial
  nodes (except for MySQL on Trusty), for deployment using Juju 2.

- mitaka-juju-1: Bundle for Mitaka OpenStack with Calico 1.4 on Xenial nodes
  (except for MySQL on Trusty), for deployment using Juju 1.

- icehouse-kilo-liberty: Bundle for Icehouse/Kilo/Liberty OpenStack with Calico
  1.3 on Trusty nodes, for deployment using Juju 1.

See the README.* files in each subdirectory, for more details.

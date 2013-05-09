name             'openstack'
maintainer       'Kakao Corp.'
maintainer_email 'charlie.choe@kakao.com'
license          'All rights reserved'
description      'Installs/Configures openstack'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

supports 'ubuntu', '= 12.04'

depends 'apt'
depends 'database'
depends 'openssl'

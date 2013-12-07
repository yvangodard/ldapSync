LdapSync
========

Présentation
------------

Cet outil est destiné à effectuer une syncrhonisation depuis une liste de membres d'un groupe OpenDirectory vers une branche GroupOfNames du LDAP.
Cet outil doit impérativement être lancé sur une machine enrolée à l'OpenDirectory.
Cet outil est un fork du script [proposé ici](http://goo.gl/lVnjFw).

Pour une aide complète, installer le script et lancez le :

    ./ldapSync.sh help


Bug report
-------------

Si vous voulez me faire remonter un bug : [ouvrir un bug](https://github.com/ygodard/ldapsync/issues).


Installation
---------

Pour installer cet outil, depuis votre terminal, une fois positionné dans le dossier dans lequel vous souhaitez installer cet outil :

	wget --no-check-certificate https://raw.github.com/yvangodard/ldapSync/master/ldapSync.sh ; sudo chmod +x ldapSync.sh


License
-------

Ce script ldapSync de [Yvan GODARD](http://www.yvangodard.me) est mis à disposition selon les termes de la licence Creative Commons 4.0 BY NC SA (Attribution - Pas d’Utilisation Commerciale - Partage dans les Mêmes Conditions).

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0"><img alt="Licence Creative Commons" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>


Limitations
-----------

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
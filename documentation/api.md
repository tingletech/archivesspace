# ASpace API Documentation
## Version: DRAFT

## REST endpoints

### Implemented

Stuff gets pulled into this area once the implementation is fairly stable

### Planned / Considered

/version
GET the version of the API

---

/repositories  
GET a (filtered) set of repositories  
POST a new repository 

/repositories/{key}  
GET a particular repository   
PUT a new* or updated repository   
_\*Can repository IDs be set by an API client?_  

---

/repositories/{key}/resources  
GET a (filtered) set of top-level resources  
POST a new top-level resource   

/repositories/{key}/resources/{key}  
GET a particular top-level resource   
PUT a new* or updated top-level resource    
_\*Can top-level resource IDs be set by an API client?_

---

/repositories/{key}/archival_objects  
GET a (filtered) set of archival objects  
POST a new archival object  

/repositories/{key}/archival_objects/{key}  
GET a particular archival object  
PUT an updated archival object  

---

/repositories/{key}/accessions  
GET a (filtered) set of accessions    
POST a new accession

/repositories/{key}/accessions/{key}  
GET a particular accession    
PUT an updated accession  

---

/agents  
GET a (filtered) set of agents  
POST a new agent  

/agents/{key}
GET a particular agent  
PUT an updated agent 

/agents/{key}/control  
GET metadata about the status of the agent representation  
_\*Note: This may be constructed by inference; this may not merit its own endpoint_  

/agents/{key}/names  
GET a (filtered) set of names for an agent  
POST a new name for an agent

/agents/{key}/names/{key}  
GET a particular name for an agent  
PUT an updated name 

/agents/{key}/contacts  
GET a (filtered) set of contact listings for an agent  
POST a new contact for an agent  

/agents/{key}/contacts/{key}  
GET a particular contact listing  
PUT an updated contact listing

/agents/{key}/descriptions  
GET a (filtered) set of descriptive statements for an agent    
POST a new agent description  
_\*Note: description statements are broken down by type; an alternative would be to have endpoints for each type_  

/agents/{key}/descriptions/{key}  
GET a particular desc. statement   
PUT an updated desc. statement  

/agents/{key}/relationships  
GET a (filtered) set of relationships the agent bears to other agents, resources, archival objects  
_\*Note: Need further clarification on how relationships are represented RESTfully_  


## Document History

<table>
	<tr>
		<td>When</td>
		<td>Who</td>
		<td>What</td>
	</tr>
	<tr>
		<td>2012-08-02</td>
		<td>Brian Hoffman</td>
		<td>Created document</td>
	</tr>
	<tr>
		<td>2012-08-03</td>
		<td>Brian Hoffman</td>
		<td>added 'repositories' node for paths nested beneath repository keys, for consistency  added endpoints for agents</td>
	</tr>
</table>










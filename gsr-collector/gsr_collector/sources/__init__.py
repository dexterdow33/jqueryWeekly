from . import ckan, courtlistener, crawler, datagov, federal_register, internet_archive

# name in config.yaml -> module with find(session, cfg) -> Iterable[Candidate]
REGISTRY = {
    "datagov": datagov,
    "ckan": ckan,
    "federal_register": federal_register,
    "courtlistener": courtlistener,
    "internet_archive": internet_archive,
    "crawler": crawler,
}

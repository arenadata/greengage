/*
 * src/include/commands/proclang.h
 *
 *-------------------------------------------------------------------------
 *
 * proclang.h
 *	  prototypes for proclang.c.
 *
 *
 *-------------------------------------------------------------------------
 */
#ifndef PROCLANG_H
#define PROCLANG_H

#include "catalog/objectaddress.h"
#include "nodes/parsenodes.h"

extern ObjectAddress CreateProceduralLanguage(CreatePLangStmt *stmt);
extern bool PLTemplateExists(const char *languageName);
extern Oid	get_language_oid(const char *langname, bool missing_ok);

#endif							/* PROCLANG_H */

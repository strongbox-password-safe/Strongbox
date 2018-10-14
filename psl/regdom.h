/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to you under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at:
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *
 * Florian Sager, 03.01.2009, sager@agitos.de, http://www.agitos.de
 * Ward van Wanrooij, 04.04.2010, ward@ward.nu
 *
 */

#ifndef _REGDOM_H_
#define _REGDOM_H_

/* public API */

extern void *loadTldTree(void);
extern void freeTldTree(void *tree);
extern void printTldTree(const void *tree, const char *prefix);

extern char *getRegisteredDomain(const char *hostname, const void *tree);
extern char *getRegisteredDomainDrop(const char *hostname, const void *tree,
                                     int drop_unknown);

#endif /*_REGDOM_H_*/

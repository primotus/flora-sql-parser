'use strict';

const { expect } = require('chai');
const { getParsedSql } = require('./util');

describe('joins', () => {
    it('should support implicit joins', () => {
        expect(getParsedSql('SELECT a.col , b.c FROM a ,b'))
            .to.equal('SELECT "a"."col", "b"."c" FROM "a", "b"');
    });

    it('should support (INNER) JOINs', () => {
        const sql = 'SELECT a FROM t1 join t2 on t1.t2id = t2.t1id';
        expect(getParsedSql(sql)).to.equal('SELECT "a" FROM "t1" INNER JOIN "t2" ON "t1"."t2id" = "t2"."t1id"');
    });

    it('should support LEFT JOINs', () => {
        const sql = 'SELECT a FROM t1 left join t2 on t1.t2id = t2.t1id';
        expect(getParsedSql(sql)).to.equal('SELECT "a" FROM "t1" LEFT JOIN "t2" ON "t1"."t2id" = "t2"."t1id"');
    });

    it('should support RIGHT JOINs', () => {
        const sql = 'SELECT a FROM t1 right join t2 on t1.t2id = t2.t1id';
        expect(getParsedSql(sql)).to.equal('SELECT "a" FROM "t1" RIGHT JOIN "t2" ON "t1"."t2id" = "t2"."t1id"');
    });

    it('should support FULL JOINs', () => {
        const sql = 'SELECT a FROM t1 full join t2 on t1.t2id = t2.t1id';
        expect(getParsedSql(sql)).to.equal('SELECT "a" FROM "t1" FULL JOIN "t2" ON "t1"."t2id" = "t2"."t1id"');
    });

    it('should support multiple joins', () => {
        const sql = 'SELECT a FROM t1 LEFT JOIN t2 ON t1.t2id = t2.t1id INNER JOIN t3 ON t1.t3id = t3.t1id';
        expect(getParsedSql(sql))
            .to.equal('SELECT "a" FROM "t1" LEFT JOIN "t2" ON "t1"."t2id" = "t2"."t1id" INNER JOIN "t3" ON "t1"."t3id" = "t3"."t1id"');
    });

    it('should support alias for base table', () => {
        const sql = 'SELECT col1 FROM awesome_table t';
        expect(getParsedSql(sql)).to.equal('SELECT "col1" FROM "awesome_table" AS "t"');
    });

    it('should support joins with tables from other databases', () => {
        const sql = 'SELECT col1 FROM t JOIN otherdb.awesome_table at ON t.id = at.tid';
        expect(getParsedSql(sql))
            .to.equal('SELECT "col1" FROM "t" INNER JOIN otherdb."awesome_table" AS "at" ON "t"."id" = "at"."tid"');
    });

    it('should support aliases in joins', () => {
        expect(getParsedSql('SELECT col1 FROM t1 LEFT JOIN awesome_table AS t2 ON t1.id = t2.t1id'))
            .to.equal('SELECT "col1" FROM "t1" LEFT JOIN "awesome_table" AS "t2" ON "t1"."id" = "t2"."t1id"');
    });

    it('should support joined subquery', () => {
        expect(getParsedSql('SELECT * FROM t1 LEFT JOIN (SELECT id, col1 FROM t2) AS someAlias ON t1.id = someAlias.id'))
            .to.equal('SELECT * FROM "t1" LEFT JOIN (SELECT "id", "col1" FROM "t2") AS "someAlias" ON "t1"."id" = "someAlias"."id"');
    });

    it('should support USING keyword (single column)', () => {
        expect(getParsedSql('SELECT * FROM t1 JOIN t2 USING (id)'))
            .to.equal('SELECT * FROM "t1" INNER JOIN "t2" USING ("id")');
    });

    it('should support USING keyword (multiple columns)', () => {
        expect(getParsedSql('SELECT * FROM t1 JOIN t2 USING (id1, id2)'))
            .to.equal('SELECT * FROM "t1" INNER JOIN "t2" USING ("id1", "id2")');
    });
});

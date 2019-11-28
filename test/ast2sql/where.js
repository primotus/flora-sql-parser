'use strict';

const { expect } = require('chai');
const { util } = require('../../');
const { getParsedSql } = require('./util');

describe('where clause', () => {
    ['<', '<=', '=', '!=', '>=', '>'].forEach((operator) => {
        it(`should support simple "${operator}" comparison`, () => {
            const sql = `SELECT a fRom db.t wHERE "type" ${operator} 3`;
            expect(getParsedSql(sql)).to.equal(`SELECT "a" FROM db."t" WHERE "type" ${operator} 3`);
        });
    });

    const operatorMap = { '=': 'IN', '!=': 'NOT IN' };
    Object.keys(operatorMap).forEach((operator) => {
        const sqlOperator = operatorMap[operator];

        it(`should convert "${operator}" to ${sqlOperator} operator for array values`, () => {
            const ast = {
                type: 'select',
                options: null,
                distinct: null,
                columns: [{ expr: { type: 'column_ref', table: null, column: 'a' }, as: null }],
                from: [{ db: null, table: 't', as: null }],
                where: {
                    type: 'binary_expr',
                    operator: operator,
                    left: { type: 'column_ref', table: null, column: 'id' },
                    right: {
                        type: 'expr_list',
                        value: [{ type: 'number', value: 1 }, { type: 'number', value: 2 }]
                    }
                },
                groupby: null,
                limit: null
            };

            expect(util.astToSQL(ast)).to.equal(`SELECT "a" FROM "t" WHERE "id" ${sqlOperator} (1, 2)`);
        });
    });

    ['IN', 'NOT IN'].forEach((operator) => {
        it(`should support ${operator} operator`, () => {
            const sql = `SELECT a FROM t WHERE id ${operator.toLowerCase()} (1, 2, 3)`;
            expect(getParsedSql(sql)).to.equal(`SELECT "a" FROM "t" WHERE "id" ${operator} (1, 2, 3)`);
        });
    });

    ['IS', 'IS NOT'].forEach((operator) => {
        it(`should support ${operator} operator`, () => {
            const sql = `SELECT a FROM t WHERE col ${operator.toLowerCase()} NULL`;
            expect(getParsedSql(sql)).to.equal(`SELECT "a" FROM "t" WHERE "col" ${operator} NULL`);
        });
    });

    it('should support query param values', () => {
        const sql = 'SELECT * FROM t where t.a > :my_param';
        expect(getParsedSql(sql)).to.equal('SELECT * FROM "t" WHERE "t"."a" > :my_param');
    });

    ['BETWEEN', 'NOT BETWEEN'].forEach((operator) => {
        it(`should support ${operator} operator`, () => {
            const sql = `SELECT a FROM t WHERE id ${operator.toLowerCase()} '1' and 1337`;
            expect(getParsedSql(sql)).to.equal(`SELECT "a" FROM "t" WHERE "id" ${operator} '1' AND 1337`);
        });
    });

    it('should support boolean values', () => {
        const sql = 'SELECT col1 FROM t WHERE col2 = false';
        expect(getParsedSql(sql)).to.equal('SELECT "col1" FROM "t" WHERE "col2" = FALSE');
    });

    it('should support string values', () => {
        expect(getParsedSql(`SELECT col1 FROM t WHERE col2 = 'foobar'`))
            .to.equal(`SELECT "col1" FROM "t" WHERE "col2" = 'foobar'`);
    });

    it('should support null values', () => {
        expect(getParsedSql('SELECT col1 FROM t WHERE col2 IS NULL'))
            .to.equal('SELECT "col1" FROM "t" WHERE "col2" IS NULL');
    });

    it('should support array values', () => {
        expect(getParsedSql('SELECT col1 FROM t WHERE col2 IN (1, 3, 5, 7)'))
            .to.equal('SELECT "col1" FROM "t" WHERE "col2" IN (1, 3, 5, 7)');
    });

    ['EXISTS', 'NOT EXISTS'].forEach((operator) => {
        it(`should support ${operator} operator`, () => {
            expect(getParsedSql(`SELECT a FROM t WHERE ${operator} (SELECT 1)`))
                .to.equal(`SELECT "a" FROM "t" WHERE ${operator} (SELECT 1)`);
        });
    });

    it('should support row value constructors', () => {
        expect(getParsedSql(`SELECT * FROM "user" WHERE (firstname, lastname) = ('John', 'Doe')`))
            .to.equal(`SELECT * FROM "user" WHERE ("firstname","lastname") = ('John','Doe')`);
    });
});

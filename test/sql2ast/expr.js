'use strict';

const { expect } = require('chai');
const { Parser } = require('../../');

const { skiploc } = require('./util');
describe('expressions', () => {
    const parser = new Parser();

    describe('function', () => {
        it('should parse functions', () => {
            const ast = parser.parse('SELECT fun(d) FROM t');

            expect(skiploc(ast.columns)).to.eql([
                {
                    expr: {
                        type: 'function',
                        name: 'fun',
                        args: {
                            type  : 'expr_list',
                            value : [ { type: 'column_ref', table: null, column: 'd' } ]
                        }
                    },
                    as: null
                }
            ]);
        });

        [
            'CURRENT_DATE',
            'CURRENT_TIME',
            'CURRENT_TIMESTAMP',
            'CURRENT_USER',
            'SESSION_USER',
            'USER',
            'SYSTEM_USER'
        ].forEach((func) => {
            it(`should parse scalar function ${func}`, () => {
                const ast = parser.parse(`SELECT ${func} FROM t`);

                expect(skiploc(ast.columns)).to.eql([
                    {
                        expr: {
                            type: 'function',
                            name: func,
                            args: {
                                type: 'expr_list',
                                value: []
                            }
                        },
                        as: null
                    }
                ]);
            });
        });
    });
});
